import simple_queue;

import jobs;

int main()
{
    SimpleQueuePoolSettings settings;
    settings.workersCount = 3;

    auto pool = new SimpleQueuePool(settings);
    pool.start;

    return 0;
}
