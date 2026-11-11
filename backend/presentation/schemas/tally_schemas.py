from pydantic import BaseModel, ConfigDict, Field


class TallyChatRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    message: str = Field(min_length=1, max_length=2000)


class TallyChatResponse(BaseModel):
    answer: str
