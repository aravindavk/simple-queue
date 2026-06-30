import serverino;

@endpoint your_function(Request r, Output output) { output ~= "Hello World!"; }

mixin ServerinoMain;
