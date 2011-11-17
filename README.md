# README

An app is defined by three URLs:
 * `/setup`                   :  used for initial trigger creation
 * `/configure/:trigger_id`   :  used to configure / reconfigure the trigger
 * `/trigger/:trigger_id`     :  used to send the actual trigger to

The first two of these URLs are the only ones used in the interface.

When an interface URL (/setup or /configure) is loaded into an iFrame it must:

 * initially send an "init" message to the parent frame on load of any page
 * accept an "initted" message which passes it an id that it should store for future communications. It should not take further actions until it has received this message.
 * send a "ready" message with its id to declare that it is ready to accept user input
 * respond to a "save" message it must trigger its save method to save the state of the trigger and respond with "saved" once it has been saved, passing back the trigger url as a parameter

This API is intentionally simple in order to provide enough flexibility whilst maintaining simplicity

This has all been wrapped up into a javascript module for further simplicity 

## Developer Notes

### Requirements

 * Ruby (app was developed using MRI 1.9.2, but 1.8.7 will likely work)
 * Rubygems
 * RVM - this isn't essential, but is really useful for keeping separate bundles of application dependencies even if you only ever install a single version of Ruby. This app has a .rvmrc file specified, so if you have RVM installed it should create a separate gemset for the application when you first change into the application directory.
 * Local DB server for development. We use PostgreSQL, but there's nothing DB specific in the app so MySQL will almost certainly work just as well.
 * Bundler gem installed >= 1.0.10

### Getting started

 * Run `bundle install`
 * Populate config/database.yml with valid connection details for your local development environment (development and test stanzas required)
 * Create database by running: `rake db:create`
 * Run migrations by running: `rake db:migrate`
 * Run tests by running: `rake`
 * Hopefully specs should now all run.

## TODO

* Get app building on Jenkins
* Add delete handler so app does something sensible when the trigger is deleted on Pachube.
