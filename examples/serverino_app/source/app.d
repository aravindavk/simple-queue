import std.stdio;

import simple_queue;
import serverino;

import jobs;

@endpoint
void reportHandler(Request request, Output output)
{
    auto report = new ReportGenerateJob;
    report.path = "/tmp/report.txt";

    report.performLater;

    output.status = 202;
    output.write("Report generation queued");
}

mixin ServerinoMain;
