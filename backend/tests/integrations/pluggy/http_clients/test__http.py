import unittest

import httpx

from integrations.pluggy.exceptions.pluggy_exception_error import PluggyExceptionError
from integrations.pluggy.http_clients._http import (
    api_key_headers,
    drop_none,
    raise_for_pluggy_error,
)

_REQUEST = httpx.Request("GET", "https://api.pluggy.ai/items/1")


def _response(status_code: int, **kwargs) -> httpx.Response:
    return httpx.Response(status_code, request=_REQUEST, **kwargs)


class TestApiKeyHeaders(unittest.TestCase):
    def test_sends_the_key_in_x_api_key(self):
        self.assertEqual(api_key_headers("key-1"), {"X-API-KEY": "key-1"})


class TestDropNone(unittest.TestCase):
    def test_removes_only_none_values(self):
        values = {"itemId": "1", "type": None, "enabled": False, "ids": ""}

        self.assertEqual(drop_none(values), {"itemId": "1", "enabled": False, "ids": ""})


class TestRaiseForPluggyError(unittest.TestCase):
    def test_a_success_response_raises_nothing(self):
        raise_for_pluggy_error(_response(200, json={"id": "1"}))

    def test_a_pluggy_error_body_raises_pluggy_exception_error(self):
        body = {"code": 404, "codeDescription": "ITEM_NOT_FOUND", "message": "Item not found"}

        with self.assertRaises(PluggyExceptionError) as raised:
            raise_for_pluggy_error(_response(404, json=body))

        self.assertEqual(raised.exception.error.code_description, "ITEM_NOT_FOUND")
        self.assertEqual(raised.exception.error.code, 404)

    def test_an_error_without_a_pluggy_body_raises_http_status_error(self):
        with self.assertRaises(httpx.HTTPStatusError):
            raise_for_pluggy_error(_response(502, text="<html>Bad Gateway</html>"))

    def test_a_json_error_that_is_not_a_pluggy_body_raises_http_status_error(self):
        with self.assertRaises(httpx.HTTPStatusError):
            raise_for_pluggy_error(_response(500, json={"detail": "oops"}))
