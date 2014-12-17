Centurion
=========

A deployment tool for Docker. Takes containers from a Docker registry and runs
them on a fleet of hosts with the correct environment variables, host volume
mappings, and port mappings. Supports rolling deployments out of the box, and
makes it easy to ship applications to Docker servers.

We're using it to run our production infrastructure.

Centurion works in a two part deployment process where the build process ships
a container to the registry, and Centurion ships containers from the registry
to the Docker fleet. Registry support is handled by the Docker command line
tools directly so you can use anything they currently support via the normal
registry mechanism.

If you haven't been using a registry, you should read up on how to do that
before trying to deploy anything with Centurion.  

Commercial Docker Registry Providers:
- Docker, Inc. [provides repositories](https://index.docker.io/), and hosts the
  main public Docker repository.
- [Quay.io](https://quay.io) from the CoreOS team

Open-source:
- The [Docker registry](https://github.com/dotcloud/docker-registry) project,
  built and maintained by Docker. You host this yourself.
- (*NEW!*) [Dogestry](https://github.com/newrelic-forks/dogestry) is an
  s3-backed Docker registry alternative that removes the requirement to set up
  a centralized registry service or host anything yourself.

Status
------

This project is under active development! The initial release on GitHub contains
one roll-up commit of all our internal code. But all internal development will
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

With rbenv you will now need to do an `rbenv rehash` and the commands should
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

### Writing configs

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
    env_vars YOUR_ENV: 'staging'
    env_vars MY_DB: 'radio-db.example.com'
    host_port 10234, container_port: 9292
    host_port 10235, container_port: 9293
    host_volume '/mnt/volume1', container_volume: '/mnt/volume2'
  end

  desc 'Production environment'
  task :production => :common do
    set_current_environment(:production)
    env_vars YOUR_ENV: 'production'
    env_vars MY_DB: 'radio-db-prod.example.com'
    host_port 22234, container_port: 9292
    host_port 23235, container_port: 9293
    command ['/bin/bash', '-c', '/path/to/server -e production']
  end
end
```

This sets up a staging and production environment and defines a `common` task
that will be run in either case. Note the dependency call in the task
definition for the `production` and `staging` tasks.  Additionally, it defines
some host ports to map, sets which servers to deploy to, and sets a custom
command. Some configuration will be provided to the containers at startup time,
in the form of environment variables.

Most of the DSL items (`host_port`, `host_volume`, `env_vars`, `host`) can be
specified more than once and will append to the configuration. However, there
can only be one `command`; the last one will take priority.

You can cause your container to be started with a specific DNS server
IP address (the equivalent of `docker run --dns 172.17.42.1 ...`) like this:
```ruby
  task :production => :common do
    set :custom_dns, '172.17.42.1'
    # ...
  end
```

If you want to name your container, use the `name` DSL item. The
actual name for the created container will have a random hex string
appended, to avoid name conflicts when you repeatedly deploy an image:
```ruby
  task :common do
    set :name, 'backend'
    # ...
  end
```
With this, the container will be named something like `backend-4f692997`.

### Interpolation

Currently there is one special string for interpolation that can be added to
any `env_var` value in the DSL. `%DOCKER_HOSTNAME%` will be replaced with the
current server's hostname in the environment variable at deployment time.


Deploying
---------

Centurion supports a number of tasks out of the box that make working with
distributed containers easy.  Here are some examples:

###Do a rolling deployment to a fleet of Docker servers

A rolling deployment will stop and start each container one at a time to make
sure that the application stays available from the viewpoint of the load
balancer. As the deploy runs, a health check will hit each container to ensure
that the application booted correctly. By default, this will be a GET request to
the root path of the application. This is configurable by adding
`set(:status_endpoint, '/somewhere/else')` in your config. The status endpoint
must respond with a valid response in the 200 status range.

````bash
$ bundle exec centurion -p radio-radio -e staging -a rolling_deploy
````

**Rolling Deployment Settings**:
You can change the following settings in your config to tune how the rolling
deployment behaves. Each of these is controlled with `set(:var_name, 'value')`.
These can be different for each environment or put into a common block if they
are the same everywhere. Settings are per-project.

 * `rolling_deploy_check_interval` => Controls how long Centurion will wait after
    seeing a container as up before moving on to the next one. This should be
    slightly longer than your load balancer check interval. Value in seconds.
    Defaults to 5 seconds.
 * `rolling_deploy_wait_time` => The amount of time to wait between unsuccessful
    health checks before retrying. Value in seconds. Defaults to 5 seconds.
 * `rolling_deploy_retries` => The number of times to retry a health check on
   the container once it is running. This count multiplied by the
   `rolling_deployment_wait_time` is the total time Centurion will wait for
   an individual container to come up before giving up as a failure. Defaults
   to 24 attempts.
 * `rolling_deploy_skip_ports` => Either a single port, or an array of ports
   that should be skipped for status checks. Status checking assumes an HTTP 
   server is on the other end and if you are deploying a container where some 
   ports are not HTTP services, this allows you to only health check the ports 
   that are. The default is an empty array.

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

###List registry images

Returns a list of all the images for this project in the registry.

````bash
$ bundle exec centurion -p radio-radio -e staging -a list
````

### Registry

Centurion needs to have access to some registry in order to pull images to
remote Docker servers. This needs to be either a hosted registry (public or
private), or [Dogestry](https://github.com/newrelic-forks/dogestry).

#### Access to the registry 

If you are not using either Dogestry, or the public registry, you may need to
provide authentication credentials.  Centurion needs to access the Docker
registry hosting your images directly to retrive image ids and tags.This is
supported in both the config file and also as command line arguments.

The command line arguments are: 
 * `--registry-user` => The username to pass to the registry
 * `--registry-password` => The password

These correspond to the following settings:

 * `registry_user`
 * `registry_password`

#### Alternative Docker Registry

Centurion normally uses the built-in registry support in the Docker daemon to
handle pushing and pulling images. But Centurion also has the ability to use
external tooling to support hosting your registry on Amazon S3. That tooling is
from a project called [Dogestry](https://github.com/newrelic-forks/dogestry).
We have recently improved that tooling substantially in coordination with the
Centurion support.

Dogestry uses the Docker daemon's import/export functionality in combination
with Amazon S3 to provide reliable hosting of images.  Setting Centurion up to
use Dogestry is pretty trivial:

 1. Install Dogestry binaries on the client from which Dogestry is run.
    Binaries are provided in the [GitHub release](https://github.com/newrelic-forks/dogestry).
 1. Add the settings necessary to get Centurion to pull from Dogestry. A config
    example is provided below:

```ruby
namespace :environment do
  task :common do
    registry :dogestry                       # Required
    set :aws_access_key_id, 'abc123'         # Required
    set :aws_secret_key, 'xyz'               # Required
    set :s3_bucket, 'docker-images-bucket'   # Required
    set :s3_region, 'us-east-1'              # Optional
  end
end
```

Future Additions
----------------

We're currently looking at the following feature additions:

 * [etcd](https://github.com/coreos/etcd) integration for configs and discovery
 * Add the ability to show all the available tasks on the command line
 * Certificate authentication
 * Customized tasks
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
