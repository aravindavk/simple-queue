# SimpleQueue - Simple Job Queue in D

Add SimpleQueue to your project by running the following dub command.

```
dub add simple-queue
```

Create the module for jobs and define the jobs by using the `SimpleQueue` interface. Implement `perform` function for your Job.

```d
// File: source/jobs/package.d

import simple_queue;

class SendMailJob : SimpleQueue
{
    string to;
    string subject;
    string body;

    void perform()
    {
        // ... implementation
    }
}

// Register all Jobs
mixin registerQueues!(SendMailJob);
```

Use this Job from your handler.

Vibe.d
```d
void userCreateHandler(HTTPServerRequest request, HTTPServerResponse response)
{
    // .. Validate the inputs and create the user record in Db
    auto user = createUser(request);
    auto mailer = new SendMailjob;
    mailer.to = user.email;
    mailer.subject = "Welcome to Awesome app";
    mailer.body = welcomeEmailContent(user);
    
    mailer.performLater;
    
    response.writeJsonBody(user);
}
```


Serverino

```d
@endpoint
void userCreateHandler(Request request, Output output)
{
    // .. Validate the inputs and create the user record in Db
    auto user = createUser(request);
    auto mailer = new SendMailjob;
    mailer.to = user.email;
    mailer.subject = "Welcome to Awesome app";
    mailer.body = welcomeEmailContent(user);
    
    mailer.performLater;
    
    output.write("User created successfully");
}
```

Handy-Httpd

```d
void userCreateHandler(HttpRequestContext ctx)
{
    // .. Validate the inputs and create the user record in Db
    auto user = createUser(ctx.request);
    auto mailer = new SendMailjob;
    mailer.to = user.email;
    mailer.subject = "Welcome to Awesome app";
    mailer.body = welcomeEmailContent(user);
    
    mailer.performLater;
    
    ctx.response.write("User created successfully");
}
```

Now add a subpackage to create the worker code.

Add below line to `dub.sdl` file.

```sdl
mainSourceFile "source/app.d"
excludedSourceFiles "source/worker.d"
```

Add subpackage,

```sdl
subPackage {
    name "worker"
    targetType "executable"
    mainSourceFile "source/worker.d"
    excludedSourceFiles "source/app.d"
    dependency simplejob version="~>0.1.0"
}
```

And create a `worker.d` in the source directory.

```d
// File: source/worker.d
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
```

Thats all! Build and start both the apps.

```
dub build
DATABASE_URL=... ./webapp
```

```
dub build :worker
DATABASE_URL=... ./webapp-worker
```

If the jobs uses database then, `DATABASE_URL` should be same for both app and the worker.
