from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse

from services.common.exceptions import (
    AlreadyExistsError,
    EmailAlreadyExistsError,
    InvalidDataError,
    NoRecurrencesError,
    NotFoundError,
    ServiceError,
    ServiceUnavailableError,
)

# status code, fixed detail and, when the app needs to tell the failure apart, a stable `code`
_STATUS: dict[type[ServiceError], tuple[int, str, str | None]] = {
    # A subclass must come before its parent: the first match of the loop wins.
    EmailAlreadyExistsError: (
        status.HTTP_409_CONFLICT,
        "Record already exists",
        "EMAIL_ALREADY_EXISTS",
    ),
    AlreadyExistsError: (status.HTTP_409_CONFLICT, "Record already exists", None),
    InvalidDataError: (status.HTTP_422_UNPROCESSABLE_CONTENT, "Invalid data", None),
    NoRecurrencesError: (
        status.HTTP_422_UNPROCESSABLE_CONTENT,
        "No recurrences to provision",
        "NO_RECURRENCES",
    ),
    NotFoundError: (status.HTTP_404_NOT_FOUND, "Record not found", None),
    ServiceUnavailableError: (
        status.HTTP_503_SERVICE_UNAVAILABLE,
        "Service unavailable",
        None,
    ),
    ServiceError: (status.HTTP_500_INTERNAL_SERVER_ERROR, "Internal error", None),
}


def register_exception_handlers(app: FastAPI) -> None:
    for error_class, (status_code, detail, code) in _STATUS.items():
        content = (
            {"detail": detail} if code is None else {"detail": detail, "code": code}
        )

        def handler(
            request: Request, exc: Exception, status_code=status_code, content=content
        ) -> JSONResponse:
            return JSONResponse(status_code=status_code, content=content)

        app.add_exception_handler(error_class, handler)
