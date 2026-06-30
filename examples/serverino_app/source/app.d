import std.format : format;

import simple_queue;
import serverino;

import jobs;

@endpoint
@route!"/task"
void reportHandler(Request request, Output output)
{
    auto report = new ReportGenerateJob;
    report.path = "/tmp/report.txt";

    auto jobId = report.performLater;

    output.status = 202;
    output.write(format("Report generation queued (Job ID: %s)", jobId));
}

mixin ServerinoMain;
