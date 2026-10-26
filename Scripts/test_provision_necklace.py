#!/usr/bin/env python3

import argparse
import csv
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import provision_necklace as provision


class FakeClient:
    def __init__(self):
        self.rows = {}
        self.create_errors = []

    def create_assignment(self, arcadot_id, game):
        if self.create_errors:
            error = self.create_errors.pop(0)
            if error is not None:
                raise error
        row = {
            "id": arcadot_id,
            "active_game": game,
            "updated_at": "2026-10-03T12:00:00Z",
        }
        self.rows[arcadot_id] = row
        return row

    def get_assignment(self, arcadot_id):
        if arcadot_id not in self.rows:
            raise provision.APIError(404, "arcadot_not_found")
        return self.rows[arcadot_id]


class FakeResponse:
    def __init__(self, status, payload):
        self.status = status
        self.payload = json.dumps(payload).encode("utf-8")

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def getcode(self):
        return self.status

    def read(self):
        return self.payload


class ProvisionNecklaceTests(unittest.TestCase):
    def test_generated_ids_are_ten_unambiguous_uppercase_characters(self):
        generated = {provision.generate_arcadot_id() for _ in range(100)}
        self.assertEqual(len(generated), 100)
        for arcadot_id in generated:
            self.assertEqual(len(arcadot_id), 10)
            self.assertTrue(set(arcadot_id) <= set(provision.ID_ALPHABET))
            self.assertFalse(set(arcadot_id) & set("01ILO"))

    def test_game_can_be_selected_interactively_or_by_flag(self):
        responses = iter(["wrong", "2"])
        with mock.patch("sys.stderr", new=io.StringIO()):
            self.assertEqual(provision.choose_game(lambda _: next(responses)), "pulse")

        args = provision.build_parser().parse_args(["--game", "orbit"])
        self.assertEqual(args.game, "orbit")

    def test_config_loads_file_and_process_environment_wins(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".env.provisioning"
            path.write_text(
                "LUMI_SUPABASE_URL=https://file.supabase.co\n"
                "LUMI_SUPABASE_PUBLISHABLE_KEY=file-key\n"
                "LUMI_PROVISIONING_TOKEN=file-token\n",
                encoding="utf-8",
            )
            config = provision.load_config(
                path,
                {"LUMI_SUPABASE_PUBLISHABLE_KEY": "environment-key"},
            )

        self.assertEqual(config.supabase_url, "https://file.supabase.co")
        self.assertEqual(config.publishable_key, "environment-key")
        self.assertEqual(config.provisioning_token, "file-token")

    def test_collision_generates_a_new_id_and_verifies_it(self):
        client = FakeClient()
        client.create_errors = [provision.APIError(409, "arcadot_already_exists"), None]
        identifiers = iter(["AAAAAAAAAA", "BBBBBBBBBB"])

        result = provision.provision_one(client, "sky-stack", id_factory=lambda: next(identifiers))

        self.assertEqual(result.id, "BBBBBBBBBB")
        self.assertEqual(result.url, "https://play.luminecklace.com/a/BBBBBBBBBB")

    def test_http_client_sends_public_and_provisioning_credentials(self):
        observed = {}

        def opener(request, timeout):
            observed["headers"] = {key.lower(): value for key, value in request.header_items()}
            observed["body"] = json.loads(request.data)
            observed["timeout"] = timeout
            return FakeResponse(
                201,
                {
                    "id": "BBBBBBBBBB",
                    "active_game": "pulse",
                    "updated_at": "2026-10-03T12:00:00Z",
                },
            )

        client = provision.ArcadotClient(
            provision.ProvisioningConfig(
                "https://project.supabase.co",
                "publishable-key",
                "provisioning-token",
            ),
            timeout=7.0,
            opener=opener,
        )
        client.create_assignment("BBBBBBBBBB", "pulse")

        self.assertEqual(observed["headers"]["apikey"], "publishable-key")
        self.assertEqual(
            observed["headers"]["x-lumi-provisioning-token"],
            "provisioning-token",
        )
        self.assertEqual(observed["body"], {"id": "BBBBBBBBBB", "game": "pulse"})
        self.assertEqual(observed["timeout"], 7.0)

    def test_connection_drop_recovers_a_successful_creation(self):
        class RecoveringClient(FakeClient):
            def create_assignment(self, arcadot_id, game):
                self.rows[arcadot_id] = {
                    "id": arcadot_id,
                    "active_game": game,
                    "updated_at": "2026-10-03T12:00:00Z",
                }
                raise provision.TransportError("connection dropped")

        result = provision.provision_one(
            RecoveringClient(),
            "pulse",
            id_factory=lambda: "CCCCCCCCCC",
        )
        self.assertEqual(result.id, "CCCCCCCCCC")

    def test_unrecoverable_connection_failure_is_reported(self):
        client = FakeClient()
        client.create_errors = [provision.TransportError("offline")]
        with self.assertRaisesRegex(provision.TransportError, "offline"):
            provision.provision_one(client, "pulse", id_factory=lambda: "CCCCCCCCCC")

    def test_verification_rejects_a_mismatched_assignment(self):
        client = FakeClient()

        def mismatched_get(_):
            return {
                "id": "OTHERID222",
                "active_game": "pulse",
                "updated_at": "2026-10-03T12:00:00Z",
            }

        client.get_assignment = mismatched_get
        with self.assertRaisesRegex(provision.ProvisioningError, "different ID or game"):
            provision.provision_one(client, "pulse", id_factory=lambda: "DDDDDDDDDD")

    def test_batch_csv_contains_verified_rows_and_refuses_overwrite(self):
        client = FakeClient()
        identifiers = iter(["EEEEEEEEEE", "FFFFFFFFFF"])
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "necklaces.csv"
            results = provision.write_batch_csv(
                output,
                client,
                "orbit",
                2,
                id_factory=lambda: next(identifiers),
            )
            with output.open(newline="", encoding="utf-8") as handle:
                rows = list(csv.DictReader(handle))
            with self.assertRaises(FileExistsError):
                provision.write_batch_csv(output, client, "orbit", 1)

        self.assertEqual([result.id for result in results], ["EEEEEEEEEE", "FFFFFFFFFF"])
        self.assertEqual(rows[0]["active_game"], "orbit")
        self.assertEqual(rows[1]["url"], "https://play.luminecklace.com/a/FFFFFFFFFF")

    def test_batch_keeps_successful_rows_when_a_later_creation_fails(self):
        client = FakeClient()
        client.create_errors = [None, provision.APIError(500, "internal_error")]
        identifiers = iter(["GGGGGGGGGG", "HHHHHHHHHH"])
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "partial.csv"
            with self.assertRaises(provision.APIError):
                provision.write_batch_csv(
                    output,
                    client,
                    "pulse",
                    2,
                    id_factory=lambda: next(identifiers),
                )
            with output.open(newline="", encoding="utf-8") as handle:
                rows = list(csv.DictReader(handle))

        self.assertEqual([row["id"] for row in rows], ["GGGGGGGGGG"])

    def test_run_requires_batch_output_and_protects_existing_files(self):
        missing_output = argparse.Namespace(
            game="pulse",
            count=2,
            output=None,
            env_file=Path("unused"),
            timeout=10.0,
        )
        with self.assertRaisesRegex(provision.ProvisioningError, "--output is required"):
            provision.run(missing_output)

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "existing.csv"
            output.write_text("keep me", encoding="utf-8")
            existing_output = argparse.Namespace(
                game="pulse",
                count=2,
                output=output,
                env_file=Path("unused"),
                timeout=10.0,
            )
            with self.assertRaisesRegex(provision.ProvisioningError, "Refusing to overwrite"):
                provision.run(existing_output)
            self.assertEqual(output.read_text(encoding="utf-8"), "keep me")

    def test_single_run_prints_url_without_printing_secrets_and_handles_clipboard_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            env_file = Path(directory) / ".env.provisioning"
            env_file.write_text(
                "LUMI_SUPABASE_URL=https://project.supabase.co\n"
                "LUMI_SUPABASE_PUBLISHABLE_KEY=publishable-secret-value\n"
                "LUMI_PROVISIONING_TOKEN=provisioning-secret-value\n",
                encoding="utf-8",
            )
            args = argparse.Namespace(
                game="pulse",
                count=1,
                output=None,
                env_file=env_file,
                timeout=10.0,
            )
            output = io.StringIO()
            client = FakeClient()

            def client_factory(_, __):
                return client

            with mock.patch.object(provision, "generate_arcadot_id", return_value="JJJJJJJJJJ"), mock.patch.object(
                provision, "copy_to_clipboard", return_value=False
            ):
                status = provision.run(args, stdout=output, client_factory=client_factory)

        rendered = output.getvalue()
        self.assertEqual(status, 0)
        self.assertIn("https://play.luminecklace.com/a/JJJJJJJJJJ", rendered)
        self.assertIn("Clipboard unavailable", rendered)
        self.assertNotIn("publishable-secret-value", rendered)
        self.assertNotIn("provisioning-secret-value", rendered)


if __name__ == "__main__":
    unittest.main()
