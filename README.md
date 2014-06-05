Centurion
=========

A deployment tool for Docker. Takes containers from a Docker registry and runs
them on a fleet of hosts with the correct environment variables, host mappings,
and port mappings. Supports rolling deployments out of the box, and makes it
easy to ship applications to Docker servers.

We're using it to run our production infrastructure.

Centurion works in a two part deployment process where the build process ships
a container to the registry, and Centurion ships containers from the registry
to the Docker fleet. Registry support is handled by the Docker command line
tools directly so you can use anything they currently support via the normal
registry mechanism.

If you haven't been using a registry, you should read up on how to do that
before trying to deploy anything with Centurion.  Docker, Inc [provide
repositories](https://index.docker.io/), including the main public repository.
Alternatively, you can [host your
own](https://github.com/dotcloud/docker-registry), or
[Quay.io](https://quay.io) is another commercial option.

Status
------

This project is under active development! The initial release on GitHub contains
one roll-up commit of all our internal code. But all internal devlopment will
now be on public GitHub. See the CONTRIBUTORS file for the contributors to the
original internal project.

Installation
------------

Centurion is a Ruby gem. It assumes that you have a working, modern-ish Ruby
(1.9.3 or higher). On Ubuntu 12.04 you can install this with the `ruby-1.9.1`
system package, for example. On OSX this is best accomplished via `rbenv` and
`ruby-build` which can be installed with [Homebrew](http://brew.sh/) or from 
[GitHub](https://github.com/sstephenson/rbenv).

Once you have a running, modern Ruby, you simply:

```
$ gem install centurion
```

With rbenv you will now need to do and `rbenv rehash` and the commands should
be available. With a non-rbenv install, assuming the gem dir is in your path,
the commands should just work now.

Configuration
-------------

Centurion expects to find configuration tasks in the current working directory.
Soon it will also support reading configuration from etcd.

We recommend putting all your configuration for multiple applications into a
single repo rather than spreading it around by project. This allows a central
choke point on configuration changes between applications and tends to work
well with the hand-off in many organizations between the build and deploy
steps. If you only have one application, or don't need this you can
decentralize the config into each repo.

It will look for configuration files in either `./config/centurion` or `.`.

The pattern at New Relic is to have a configs repo with a `Gemfile` that
sources the Centurion gem. If you want Centurion to set up the structure for
you and to create a sample config, you can simply run `centurionize` once you
have the Ruby Gem installed.

Centurion ships with a simple scaffolding tool that will setup a new config repo for
you, as well as scaffold individual project configs. Here's how you run it:

```bash
$ centurionize -p <your_project>
```

`centurionize` relies on Bundler being installed already. Running the command
will have the following effects:

 * Ensure that a `config/centurion` directory exists
 * Scaffold an example config for your project (you can specify the registry)
 * Ensure that a Gemfile is present
 * Ensure that Centurion is in the Gemfile (if absent it just appends it)

Any time you add a new project you can scaffold it in the same manner even
in the same repo.

###Writing configs

If you used `centurionize` you will have a base config scaffolded for you.
But you'll still need to specify all of your configuration.

Configs are in the form of a Rake task that uses a built-in DSL to make them
easy to write. Here's a sample config for a project called "radio-radio" that
would go into `config/centurion/radio-radio.rake`:

```ruby
namespace :environment do
  task :common do
    set :image, 'example.com/newrelic/radio-radio'
    host 'docker-server-1.example.com'
	host 'docker-server-2.example.com'
  end

  desc 'Staging environment'
  task :staging => :common do
	set_current_environment(:staging)
	env_var YOUR_ENV: 'staging'
	env_var MY_DB: 'radio-db.example.com'
    host_port 10234, container_port: 9292
    host_port 10235, container_port: 9293
	hot_volume '/mnt/volume1', container_volume: '/mnt/volume2'
  end

  desc 'Production environment'
  task :production => :common do
	set_current_environment(:production)
	env_var YOUR_ENV: 'production'
	env_var MY_DB: 'radio-db-prod.example.com'
    host_port 22234, container_port: 9292
    host_port 23235, container_port: 9293
  end
end
```

This sets up a staging and productionenvironment and defines a `common` task
that will be run in either case. Note the dependency call in the task
definition for the `production` and `staging` tasks.  Additionally, it defines
some host ports to map and sets which servers to deploy to. Some configuration
will provided to the containers at startup time, in the form of environment
variables.

All of the DSL items (`host_port`, `host_volume`, `env_var`, `host`) can be
specified more than once and will append to the configuration.

Deploying
---------

Centurion supports a number of tasks out of the box that make working with
distributed containers easy.  Here are some examples:

###Do a rolling deployment to a fleet of Docker servers

A rolling deployment will stop and start each container one at a time to make
sure that the application stays available from the viewpoint of the load
balancer.  Currently assumes a valid response in the 200 range on
`/status/check`. This endpoint will shortly be settable in your config.

````bash
$ bundle exec centurion -p radio-radio -e staging -a rolling_deploy
````

###Deploy a project to a fleet of Docker servers

This will hard stop, then start containers on all the specified hosts. This
is not recommended for apps where one endpoint needs to be available at all
times.

````bash
$ bundle exec centurion -p radio-radio -e staging -a deploy
````

###Deploy a bash console on a host

This will give you a command line shell with all of your existing environment
passed to the container. The `CMD` from the `Dockerfile` will be replaced
with `/bin/bash`. It will use the first host from the host list.

````bash
$ bundle exec centurion -p radio-radio -e staging -a deploy_console
````

###List all the tags running on your servers for a particular project

Returns a nicely-formatted list of all the current tags and which machines they
are running on. Gives a unique list of tags across all hosts as well.  This is
useful for validating the state of the deployment in the case where something
goes wrong mid-deploy.

```bash
$ bundle exec centurion -p radio-radio -e staging -a list:running_container_tags
```

###List all the containers currently running for this project

Returns a (as yet not very nicely formatted) list of all the containers for
this project on each of the servers from the config.

```bash
$ bundle exec centurion -p radio-radio -e staging -a list:running_containers
```

###List registry containers

Returns a list of all the containers for this project in the registry.

````bash
$ bundle exec centurion -p radio-radio -e staging -a list
````

Future Additions
----------------

We're currently looking at the following feature additions:

 * [etcd](https://github.com/coreos/etcd) integration for configs and discovery
 * Add the ability to show all the available tasks on the command line
 * Certificate authentication
 * Customized tasks
 * Settable status page URL for rolling deployment
 * Dynamic host allocation to a pool of servers

Contributions
-------------

Contributions are more than welcome. Bug reports with specific reproduction
steps are great. If you have a code contribution you'd like to make, open a
pull request with suggested code.

Pull requests should:

 * Clearly state their intent in the title
 * Have a description that explains the need for the changes
 * Include tests!
 * Not break the public API

If you are simply looking to contribute to the project, taking on one of the
items in the "Future Additions" section above would be a great place to start.
Ping us to let us know you're working on it by opening a GitHub Issue on the
project.

By contributing to this project you agree that you are granting New Relic a
non-exclusive, non-revokable, no-cost license to use the code, algorithms,
patents, and ideas in that code in our products if we so choose. You also agree
the code is provided as-is and you provide no warranties as to its fitness or
correctness for any purpose

Copyright (c) 2014 New Relic, Inc. All rights reserved.
