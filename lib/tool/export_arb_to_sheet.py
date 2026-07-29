#!/usr/bin/env python3
"""Append missing ARB keys and translations to Google Sheets."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


LOCALE_PATTERN = re.compile(r"^.+_([a-zA-Z]{2,3}(?:_[A-Z]{2})?)\.arb$")
REQUIRED_HEADERS = ("label", "description", "meta")
SHEETS_SCOPE = "https://www.googleapis.com/auth/spreadsheets"


@dataclass(frozen=True)
class TranslationRow:
    label: str
    description: str
    meta: str
    translations: dict[str, str]


@dataclass(frozen=True)
class ArbTab:
    name: str
    locales: tuple[str, ...]
    rows: tuple[TranslationRow, ...]


def _locale_from_path(path: Path) -> str:
    match = LOCALE_PATTERN.match(path.name)
    if match is None:
        raise ValueError(f"Cannot determine locale from ARB filename: {path}")
    return match.group(1)


def _read_arb(path: Path) -> dict[str, Any]:
    try:
        content = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"Cannot read {path}: {error}") from error
    if not isinstance(content, dict):
        raise ValueError(f"ARB root must be a JSON object: {path}")
    return content


def _metadata_for_key(
    key: str,
    locale_data: dict[str, dict[str, Any]],
) -> tuple[str, str]:
    for content in locale_data.values():
        raw_meta = content.get(f"@{key}")
        if not isinstance(raw_meta, dict):
            continue
        metadata = dict(raw_meta)
        description = metadata.pop("description", "")
        return str(description), json.dumps(
            metadata,
            ensure_ascii=False,
            separators=(",", ":"),
        )
    return "", "{}"


def load_arb_tabs(arb_root: Path, allow_empty: bool) -> tuple[ArbTab, ...]:
    if not arb_root.is_dir():
        raise ValueError(f"ARB root does not exist: {arb_root}")

    tabs: list[ArbTab] = []
    for tab_dir in sorted(path for path in arb_root.iterdir() if path.is_dir()):
        arb_files = sorted(tab_dir.glob("*.arb"))
        if not arb_files:
            continue

        locale_data = {
            _locale_from_path(path): _read_arb(path) for path in arb_files
        }
        locales = tuple(locale_data)
        labels = sorted(
            {
                key
                for content in locale_data.values()
                for key in content
                if not key.startswith("@")
            }
        )
        rows: list[TranslationRow] = []

        for label in labels:
            translations: dict[str, str] = {}
            missing_locales: list[str] = []
            for locale, content in locale_data.items():
                value = content.get(label)
                if not isinstance(value, str) or not value.strip():
                    missing_locales.append(locale)
                    translations[locale] = ""
                else:
                    translations[locale] = value

            if missing_locales and not allow_empty:
                missing = ", ".join(missing_locales)
                raise ValueError(
                    f'{tab_dir.name}/{label} is empty for locales: {missing}'
                )

            description, meta = _metadata_for_key(label, locale_data)
            rows.append(
                TranslationRow(
                    label=label,
                    description=description,
                    meta=meta,
                    translations=translations,
                )
            )

        tabs.append(
            ArbTab(
                name=tab_dir.name,
                locales=locales,
                rows=tuple(rows),
            )
        )

    if not tabs:
        raise ValueError(f"No ARB tabs found under {arb_root}")
    return tuple(tabs)


def _cell(row: list[str], index: int) -> str:
    return row[index] if index < len(row) else ""


def _column_name(index: int) -> str:
    result = ""
    value = index + 1
    while value:
        value, remainder = divmod(value - 1, 26)
        result = chr(65 + remainder) + result
    return result


def _connect(credentials_path: Path, spreadsheet_id: str):
    try:
        import gspread
        from google.oauth2.service_account import Credentials
    except ImportError as error:
        raise RuntimeError(
            "Missing Python dependencies. Run: "
            "python3 -m pip install -r lib/tool/requirements-l10n.txt"
        ) from error

    credentials = Credentials.from_service_account_file(
        str(credentials_path),
        scopes=[SHEETS_SCOPE],
    )
    try:
        return gspread.authorize(credentials).open_by_key(spreadsheet_id)
    except Exception as error:
        raise RuntimeError(
            "Cannot open Google Sheet. Verify --sheet, share the spreadsheet "
            "with client_email from credentials, and grant Editor access."
        ) from error


def sync_tab(spreadsheet, tab: ArbTab, apply: bool) -> tuple[int, int]:
    try:
        worksheet = spreadsheet.worksheet(tab.name)
    except Exception as error:
        raise ValueError(
            f'Google Sheet tab "{tab.name}" was not found'
        ) from error

    values = worksheet.get_all_values()
    headers = list(values[0]) if values else []
    if headers and tuple(headers[:3]) != REQUIRED_HEADERS:
        raise ValueError(
            f'{tab.name}: first columns must be '
            f'{" | ".join(REQUIRED_HEADERS)}, got {" | ".join(headers[:3])}'
        )
    if not headers:
        headers = list(REQUIRED_HEADERS)

    added_headers: list[tuple[int, str]] = []
    for locale in tab.locales:
        if locale not in headers:
            headers.append(locale)
            added_headers.append((len(headers) - 1, locale))

    label_index = headers.index("label")
    existing_rows: dict[str, tuple[int, list[str]]] = {}
    for sheet_row_number, row in enumerate(values[1:], start=2):
        label = _cell(row, label_index).strip()
        if not label:
            continue
        if label in existing_rows:
            raise ValueError(f'{tab.name}: duplicate label "{label}"')
        existing_rows[label] = (sheet_row_number, row)

    appended: list[list[str]] = []
    fill_updates: list[dict[str, Any]] = []
    for arb_row in tab.rows:
        existing = existing_rows.get(arb_row.label)
        if existing is None:
            row_by_header = {
                "label": arb_row.label,
                "description": arb_row.description,
                "meta": arb_row.meta,
                **arb_row.translations,
            }
            appended.append([row_by_header.get(header, "") for header in headers])
            continue

        sheet_row_number, current_row = existing
        for locale, translation in arb_row.translations.items():
            column_index = headers.index(locale)
            if translation and not _cell(current_row, column_index).strip():
                fill_updates.append(
                    {
                        "range": (
                            f"{_column_name(column_index)}{sheet_row_number}"
                        ),
                        "values": [[translation]],
                    }
                )

    print(f"\n[{tab.name}]")
    for _, locale in added_headers:
        print(f"  add locale column: {locale}")
    for row in appended:
        print(f"  append key: {row[label_index]}")
    for update in fill_updates:
        print(f"  fill empty cell: {update['range']}")
    if not added_headers and not appended and not fill_updates:
        print("  no changes")

    if apply:
        header_updates = [
            {
                "range": f"{_column_name(index)}1",
                "values": [[locale]],
            }
            for index, locale in added_headers
        ]
        updates = header_updates + fill_updates
        if not values:
            updates = [
                {
                    "range": f"A1:{_column_name(len(headers) - 1)}1",
                    "values": [headers],
                }
            ] + fill_updates
        if updates:
            worksheet.batch_update(updates, value_input_option="RAW")
        if appended:
            worksheet.append_rows(
                appended,
                value_input_option="RAW",
                insert_data_option="INSERT_ROWS",
            )

    return len(appended), len(fill_updates)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Add missing ARB keys to Google Sheets without overwriting "
            "existing translations."
        )
    )
    parser.add_argument("--credentials", required=True, type=Path)
    parser.add_argument("--sheet", required=True)
    parser.add_argument(
        "--arb-root",
        type=Path,
        default=Path("lib/src/l10n"),
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write changes. Without this flag the command is a dry run.",
    )
    parser.add_argument(
        "--allow-empty",
        action="store_true",
        help="Allow keys that are missing in one or more locale files.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        tabs = load_arb_tabs(args.arb_root, args.allow_empty)
        spreadsheet = _connect(args.credentials, args.sheet)
        appended = 0
        filled = 0
        for tab in tabs:
            tab_appended, tab_filled = sync_tab(
                spreadsheet,
                tab,
                args.apply,
            )
            appended += tab_appended
            filled += tab_filled
    except (RuntimeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    mode = "applied" if args.apply else "dry run"
    print(f"\n{mode}: {appended} keys appended, {filled} empty cells filled")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
