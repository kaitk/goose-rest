# docs/tutorial/06-schema-languages.md: a field with format: ascii, written with
# pydantic 2.x. Running it prints the JSON Schema, which holds "format": "ascii"
# and "maxLength": 7.
import json

from pydantic import BaseModel, Field


class Project(BaseModel):
    color: str = Field(max_length=7, json_schema_extra={"format": "ascii"})


print(json.dumps(Project.model_json_schema(), indent=2))
