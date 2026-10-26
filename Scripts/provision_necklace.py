#!/usr/bin/env python3
"""Provision Lumi Arcade necklaces without exposing Supabase server credentials."""

from __future__ import annotations

import argparse
import csv
import json
import os
import secrets
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping, TextIO


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_ENV_FILE = ROOT / ".env.provisioning"
FUNCTION_PATH = "/functions/v1/arcadot-game"
INVOCATION_BASE_URL = "https://play.luminecklace.com/a"
GAMES = ("sky-stack", "pulse", "orbit")
GAME_NAMES = {
    "sky-stack": "Sky Stack",
    "pulse": "Pulse",
    "orbit": "Orbit",
}
ID_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
ID_LENGTH = 10
MAX_ID_ATTEMPTS = 5


class ProvisioningError(Exception):
    """A safe, user-facing provisioning failure."""


class APIError(ProvisioningError):
    def __init__(self, status: int, code: str):
        self.status = status
        self.code = code
        super().__init__(f"Arcadot service returned HTTP {status}: {code}")


class TransportError(ProvisioningError):
    """The Arcadot service could not be reached or returned malformed data."""


@dataclass(frozen=True)
class ProvisioningConfig:
    supabase_url: str
    publishable_key: str
    provisioning_token: str


@dataclass(frozen=True)
class ProvisionedNecklace:
    id: str
    active_game: str
    url: str
    provisioned_at: str


def parse_env_file(path: Path) -> dict[str, str]:
    """Read the small KEY=VALUE provisioning file without third-party packages."""
    if not path.exists():
        return {}

    values: dict[str, str] = {}
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].lstrip()
        if "=" not in line:
            raise ProvisioningError(f"Invalid environment line {line_number} in {path}")
        key, value = (part.strip() for part in line.split("=", 1))
        if not key:
            raise ProvisioningError(f"Invalid environment line {line_number} in {path}")
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        values[key] = value
    return values


def load_config(
    env_file: Path = DEFAULT_ENV_FILE,
    environment: Mapping[str, str] | None = None,
) -> ProvisioningConfig:
    file_values = parse_env_file(env_file)
    process_values = os.environ if environment is None else environment

    def value(key: str) -> str:
        return process_values.get(key, file_values.get(key, "")).strip()

    config = ProvisioningConfig(
        supabase_url=value("LUMI_SUPABASE_URL").rstrip("/"),
        publishable_key=value("LUMI_SUPABASE_PUBLISHABLE_KEY"),
        provisioning_token=value("LUMI_PROVISIONING_TOKEN"),
    )
    missing = [
        key
        for key, configured in (
            ("LUMI_SUPABASE_URL", config.supabase_url),
            ("LUMI_SUPABASE_PUBLISHABLE_KEY", config.publishable_key),
            ("LUMI_PROVISIONING_TOKEN", config.provisioning_token),
        )
        if not configured
    ]
    if missing:
        joined = ", ".join(missing)
        raise ProvisioningError(
            f"Missing {joined}. Copy .env.provisioning.example to .env.provisioning and fill it in."
        )

    parsed_url = urllib.parse.urlparse(config.supabase_url)
    if parsed_url.scheme not in {"http", "https"} or not parsed_url.netloc:
        raise ProvisioningError("LUMI_SUPABASE_URL must be a complete HTTP or HTTPS URL")
    return config


class ArcadotClient:
    def __init__(
        self,
        config: ProvisioningConfig,
        timeout: float = 10.0,
        opener: Callable[..., object] = urllib.request.urlopen,
    ) -> None:
        self.endpoint = f"{config.supabase_url}{FUNCTION_PATH}"
        self.publishable_key = config.publishable_key
        self.provisioning_token = config.provisioning_token
        self.timeout = timeout
        self.opener = opener

    def create_assignment(self, arcadot_id: str, game: str) -> dict[str, object]:
        return self._request(
            "POST",
            {"id": arcadot_id, "game": game},
            provisioning=True,
            expected_status=201,
        )

    def get_assignment(self, arcadot_id: str) -> dict[str, object]:
        query = urllib.parse.urlencode({"id": arcadot_id})
        return self._request("GET", expected_status=200, query=query)

    def _request(
        self,
        method: str,
        body: dict[str, str] | None = None,
        *,
        provisioning: bool = False,
        expected_status: int,
        query: str | None = None,
    ) -> dict[str, object]:
        url = self.endpoint if query is None else f"{self.endpoint}?{query}"
        headers = {"accept": "application/json", "apikey": self.publishable_key}
        data = None
        if body is not None:
            headers["content-type"] = "application/json"
            data = json.dumps(body).encode("utf-8")
        if provisioning:
            headers["x-lumi-provisioning-token"] = self.provisioning_token
        request = urllib.request.Request(url, data=data, headers=headers, method=method)

        try:
            with self.opener(request, timeout=self.timeout) as response:
                status = response.getcode()
                raw_body = response.read()
        except urllib.error.HTTPError as error:
            code = self._error_code(error.read())
            raise APIError(error.code, code) from None
        except (OSError, urllib.error.URLError) as error:
            raise TransportError(f"Could not reach the Arcadot service: {error}") from None

        if status != expected_status:
            raise APIError(status, self._error_code(raw_body))
        try:
            payload = json.loads(raw_body)
        except (json.JSONDecodeError, UnicodeDecodeError):
            raise TransportError("Arcadot service returned malformed JSON") from None
        if not isinstance(payload, dict):
            raise TransportError("Arcadot service returned an unexpected response")
        return payload

    @staticmethod
    def _error_code(raw_body: bytes) -> str:
        try:
            payload = json.loads(raw_body)
        except (json.JSONDecodeError, UnicodeDecodeError):
            return "unexpected_response"
        if isinstance(payload, dict) and isinstance(payload.get("error"), str):
            return payload["error"]
        return "unexpected_response"


def generate_arcadot_id() -> str:
    return "".join(secrets.choice(ID_ALPHABET) for _ in range(ID_LENGTH))


def necklace_url(arcadot_id: str) -> str:
    return f"{INVOCATION_BASE_URL}/{arcadot_id}"


def row_to_necklace(row: Mapping[str, object], expected_id: str, expected_game: str) -> ProvisionedNecklace:
    if row.get("id") != expected_id or row.get("active_game") != expected_game:
        raise ProvisioningError("Arcadot verification returned a different ID or game")
    updated_at = row.get("updated_at")
    if not isinstance(updated_at, str) or not updated_at:
        raise ProvisioningError("Arcadot verification did not return a timestamp")
    return ProvisionedNecklace(
        id=expected_id,
        active_game=expected_game,
        url=necklace_url(expected_id),
        provisioned_at=updated_at,
    )


def provision_one(
    client: ArcadotClient,
    game: str,
    *,
    id_factory: Callable[[], str] | None = None,
    max_attempts: int = MAX_ID_ATTEMPTS,
) -> ProvisionedNecklace:
    make_id = generate_arcadot_id if id_factory is None else id_factory
    for _ in range(max_attempts):
        arcadot_id = make_id()
        try:
            client.create_assignment(arcadot_id, game)
        except APIError as error:
            if error.status == 409:
                continue
            raise
        except TransportError as create_error:
            # The POST may have succeeded before the connection dropped. Resolve the
            # generated ID once before reporting a failure so reruns do not orphan it.
            try:
                recovered = client.get_assignment(arcadot_id)
                return row_to_necklace(recovered, arcadot_id, game)
            except ProvisioningError:
                raise create_error from None

        verified = client.get_assignment(arcadot_id)
        return row_to_necklace(verified, arcadot_id, game)

    raise ProvisioningError(
        f"Could not generate an unused necklace ID after {max_attempts} attempts"
    )


def choose_game(input_fn: Callable[[str], str] = input) -> str:
    prompt = "Starting game — 1: Sky Stack, 2: Pulse, 3: Orbit: "
    choices = {"1": "sky-stack", "2": "pulse", "3": "orbit"}
    while True:
        choice = input_fn(prompt).strip().lower()
        if choice in choices:
            return choices[choice]
        if choice in GAMES:
            return choice
        print("Choose 1, 2, 3, sky-stack, pulse, or orbit.", file=sys.stderr)


def copy_to_clipboard(value: str) -> bool:
    try:
        result = subprocess.run(
            ["pbcopy"],
            input=value,
            text=True,
            capture_output=True,
            check=False,
        )
    except OSError:
        return False
    return result.returncode == 0


def write_batch_csv(
    path: Path,
    client: ArcadotClient,
    game: str,
    count: int,
    *,
    id_factory: Callable[[], str] | None = None,
    on_success: Callable[[int, ProvisionedNecklace], None] | None = None,
) -> list[ProvisionedNecklace]:
    necklaces: list[ProvisionedNecklace] = []
    with path.open("x", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(
            output,
            fieldnames=("id", "active_game", "url", "provisioned_at"),
        )
        writer.writeheader()
        output.flush()
        for index in range(1, count + 1):
            necklace = provision_one(client, game, id_factory=id_factory)
            writer.writerow(
                {
                    "id": necklace.id,
                    "active_game": necklace.active_game,
                    "url": necklace.url,
                    "provisioned_at": necklace.provisioned_at,
                }
            )
            output.flush()
            necklaces.append(necklace)
            if on_success is not None:
                on_success(index, necklace)
    return necklaces


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Create and verify permanent Lumi Arcade necklace URLs."
    )
    parser.add_argument("--game", choices=GAMES, help="Starting game; prompts when omitted")
    parser.add_argument("--count", type=int, default=1, help="Number of necklaces (default: 1)")
    parser.add_argument("--output", type=Path, help="CSV path required when --count is greater than 1")
    parser.add_argument("--env-file", type=Path, default=DEFAULT_ENV_FILE)
    parser.add_argument("--timeout", type=float, default=10.0, help="Network timeout in seconds")
    return parser


def run(
    args: argparse.Namespace,
    *,
    input_fn: Callable[[str], str] = input,
    stdout: TextIO = sys.stdout,
    client_factory: Callable[[ProvisioningConfig, float], ArcadotClient] = ArcadotClient,
) -> int:
    if args.count < 1:
        raise ProvisioningError("--count must be at least 1")
    if args.count > 1 and args.output is None:
        raise ProvisioningError("--output is required when --count is greater than 1")
    if args.output is not None and args.output.exists():
        raise ProvisioningError(f"Refusing to overwrite existing file: {args.output}")
    if args.timeout <= 0:
        raise ProvisioningError("--timeout must be greater than zero")

    game = args.game or choose_game(input_fn)
    config = load_config(args.env_file)
    client = client_factory(config, args.timeout)

    if args.output is not None:
        def report(index: int, necklace: ProvisionedNecklace) -> None:
            print(f"[{index}/{args.count}] {necklace.id}  {necklace.url}", file=stdout)

        write_batch_csv(args.output, client, game, args.count, on_success=report)
        print(f"Saved {args.count} necklace URL(s) to {args.output}", file=stdout)
        return 0

    necklace = provision_one(client, game)
    print("Necklace provisioned", file=stdout)
    print(f"ID: {necklace.id}", file=stdout)
    print(f"Starting game: {GAME_NAMES[necklace.active_game]}", file=stdout)
    print(f"NFC URL: {necklace.url}", file=stdout)
    if copy_to_clipboard(necklace.url):
        print("Copied NFC URL to the clipboard.", file=stdout)
    else:
        print("Clipboard unavailable; copy the NFC URL shown above.", file=stdout)
    return 0


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return run(args)
    except FileExistsError:
        print(f"Error: refusing to overwrite existing file: {args.output}", file=sys.stderr)
    except (ProvisioningError, OSError) as error:
        print(f"Error: {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
