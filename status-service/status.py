from fastapi import FastAPI, Request
import logging
import logging.handlers
import json
from pydantic import BaseModel


class InstallStatus(BaseModel):
    name: str
    description: str
    event_type: str
    origin: str
    timestamp: float
    level: str

app = FastAPI()

log = logging.getLogger("status")
log.setLevel(logging.DEBUG)
log_fmt = logging.Formatter(fmt="status: %(message)s")
syslog_handler = logging.handlers.SysLogHandler()
syslog_handler.setFormatter(log_fmt)
log.addHandler(syslog_handler)


@app.post("/hooks/install-status")
async def status(status: InstallStatus, request: Request):
    if status.name == "subiquity/Meta/status_GET":
        return

    indent = len(status.name.split("/")) - 1
    event = "{:7}".format(status.event_type + ":")
    log.info(f"{request.client.host} {event} {' '*indent}{status.name}: {status.description}")

@app.post("/hooks/install-finished")
async def finished(request: Request):
    log.info(f"{request.client.host}    * * * * * * Install Complete * * * * * *")
