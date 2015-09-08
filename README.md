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
- (*NEW!*) [Dogestry](https://github.com/dogestry/dogestry) is an
  s3-backed Docker registry alternative that removes the requirement to set up
  a centralized registry service or host anything yourself.

Status
------

This project is under active development! The initial release on GitHub contains
one roll-up commit of all our internal code. But all internal development will
now be on public GitHub. See the CONTRIBUTORS file for the contributors to the
original internal project.

The **current stable release** is 1.6.0.

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

Centurion expects to find configuration tasks in the current working directory
tree.

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
    set :dns, '172.17.42.1'
    # ...
  end
```

### Container Names

This is the name that shows up in the `docker ps` output. It's the name
of the container, not the hostname inside the container. By default
the container will be named using the name of the project as the base
of the name.

If you want to name your container something other than the project name,
use the `name` setting. The actual name for the created container will
have a random hex string appended, to avoid name conflicts when you repeatedly
deploy a project:

```ruby
  task :common do
    set :name, 'backend'
    # ...
  end
```
With this, the container will be named something like `backend-4f692997`.

### Container Hostnames

If you don't specify a hostname to use inside your container, the container
will be given a hostname matching the container ID. This probably is good for
a lot of situations, but it might not be good for yours. If you need to have
a specific hostname, you can ask Centurion to do that:

```ruby
set :container_hostname, 'yourhostname'
```

That will make *all* of your containers named 'yourhostname'. If you want to do
something more dynamic, you can pass a `Proc` or a lambda like this:

```ruby
set :container_hostname, ->(hostname) { "#{hostname}.example.com" }
```

The lambda will be passed the current server's hostname. So, this example will
cause ".example.com" to be appended to the hostname of each Docker host during
deployment.

*If you want to restore the old behavior from Centurion 1.6.0* and earlier, you
can do the following:

```ruby
set :container_hostname, ->(hostname) { hostname }
```

That will cause the container hostname to match the server's hostname.

### Network modes

You may specify the network mode you would like a container to use via:

```ruby
set :network_mode, 'networkmode'
```

Docker (and therefore Centurion) supports one of `bridge` (the default), `host`,
and `container:<container-id>` for this argument.

*Note:* While `host_port` remains required, the mappings specified in it are
*ignored* when using `host` and `container...` network modes.

### CGroup Resource Constraints

Limits on memory and CPU can be specified with the `memory` and `cpu_shares`
settings. Both of these expect a 64-bit integer describing the number of
bytes, and the number of CPU shares, respectively.

For example, to limit the memory to 1G, and the cpu time slice to half the
normal length, include the following:

```ruby
memory 1.gigabyte
cpu_shares 512
```

For more information on Docker's CGroup limits see [the Docker
docs](https://docs.docker.com/reference/run/#runtime-constraints-on-cpu-and-memory).

### Adding Extended Capabilities

Additional kernel capabilities may be granted to containers, permitting them
device access they do not normally have. You may specify these as follows:

```ruby
add_capability 'SOME_CAPABILITY'
add_capability 'ANOTHER_CAPABILITY'
drop_capability 'SOMEOTHER_CAPABILITY'
```

You may also ask for all but a few capabilities as follows:

```ruby
add_capability 'ALL'
drop_capability 'SOME_CAPABILITY'
```

For more information on which kernel capabilities may be specified, see the
[Docker docs](https://docs.docker.com/reference/run/#runtime-privilege-linux-capabilities-and-lxc-configuration).

### Interpolation

Currently there a couple of special strings for interpolation that can be added
to any `env_var` value in the DSL. `%DOCKER_HOSTNAME%` will be replaced with
the current server's hostname in the environment variable at deployment time.
Also `%DOCKER_HOST_IP%` will be replaced with the *public* IP address of the
Docker server using a `getaddrinfo` call on the client.

### Use TLS certificate

Centurion can use your existing Docker TLS certificates when using Docker with
TLS support. In doing so you have 2 choices.

#### Your certificate files are in `~/.docker/`

You just need to enable the tls mode as the following:

```ruby
  task :production => :common do
    set :tlsverify, true
    # ...
  end
```

Centurion will only set the `--tlsverify` to true and Docker will read your
certificate from the `~/.docker/` path.

#### Your certificate files are not in `~/.docker/`

Given your files are in `/usr/local/certs/`
You have to set the following keys:

```ruby
  task :production => :common do
    set :tlscacert, '/usr/local/certs/ca.pem'
    set :tlscert, '/usr/local/certs/ssl.crt'
    set :tlskey, '/usr/local/certs/ssl.key'
    # ...
  end
```

Deploying
---------

Centurion supports a number of tasks out of the box that make working with
distributed containers easy.  Here are some examples:

###Do a rolling deployment to a fleet of Docker servers

A rolling deployment will stop and start each container one at a time to make
sure that the application stays available from the viewpoint of the load
balancer. As the deploy runs, a health check will hit each container to ensure
that the application booted correctly. By default, this will be a GET request to
the root path of the application. The healthcheck endpoint is configurable by adding
`set(:status_endpoint, '/somewhere/else')` in your config. The status endpoint
must respond with a valid response in the 200 status range.

````bash
$ bundle exec centurion -p radio-radio -e staging -a rolling_deploy
````

**Custom Health Check**:
You can use a custom health check by specifying a callable object (anything that
responds to :call), e.g. a Proc, lambda, or method. This method will be invoked with
the host url, the port that needs to be checked, and the specified endpoint(via
`set(:status_endpoint, '/somewhere/else')`). If the port is ready, health check
should return a truthy value, falsey otherwise. Here's an example of a custom
health check that verifies that an elasticsearch node is up and has joined the
cluster.

````ruby
def cluster_green?(target_server, port, endpoint)
  response = begin
    Excon.get("http://#{target_server.hostname}:#{port}#{endpoint}")
  rescue Excon::Errors::SocketError
    warn "Elasticsearch node not yet up"
    nil
  end

  return false unless response
  !JSON.parse(response)['timed_out']
end

task :production => :common do
  set_current_environment(:production)
  set :status_endpoint, "/_cluster/health?wait_for_status=green&wait_for_nodes=2"
  health_check method(:cluster_green?)
  host_port 9200, container_port: 9200
  host 'es-01.example.com'
  host 'es-02.example.com'
end
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
   that should be skipped for status checks. By default status checking assumes
   an HTTP server is on the other end and if you are deploying a container where some
   ports are not HTTP services, this allows you to only health check the ports
   that are. The default is an empty array. If you have non-HTTP services that you
   want to check, see Custom Health Checks in the previous section.

###Deploy a project to a fleet of Docker servers

This will hard stop, then start containers on all the specified hosts. This
is not recommended for apps where one endpoint needs to be available at all
times. It is fast.

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
private), or [Dogestry](https://github.com/dogestry/dogestry).

#### Access to the registry

If you are not using either Dogestry, or the public registry, you may need to
provide authentication credentials.  Centurion needs to access the Docker
registry hosting your images directly to retrive image ids and tags. This is
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
from a project called [Dogestry](https://github.com/dogestry/dogestry).
We have recently improved that tooling substantially in coordination with the
Centurion support.

Dogestry uses the Docker daemon's import/export functionality in combination
with Amazon S3 to provide reliable hosting of images.  Setting Centurion up to
use Dogestry is pretty trivial:

 1. Create an S3 bucket and download the credentials to let you access the
    bucket. Generally these are IAM user keys.
 1. Install Dogestry binaries on the client from which Dogestry is run.
    Binaries are provided in the [GitHub release](https://github.com/dogestry/dogestry).
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

**TLS with Dogestry**: Because this involves a little passing around of both
settings and environment variables, there are a couple of things to verify to
make sure everything is passed properly between Centurion and Dogestry. If your
keys have the default names and are in located in the path represented by
`DOCKER_CERT_PATH` in your environment, this should just work. Otherwise you'll
need to be sure to `set :tlsverify, true` and *also* set the TLS cert names as
decribed above. 

Development
-----------

Centurion supports a few features to make development easier when
building your deployment tooling or debugging your containers.

#### Overriding Environment Variables

Sometimes when you're doing development you want to try out some configuration
settings in environment variables that aren't in the config yet. Or perhaps you
want to override existing settings to test with. You can provide the
`--override-env` command line flag with some overrides or new variables to set.
Here's how to use it:

```bash
$ centurion -e development -a deploy -p radio-radio --override-env=SERVICE_PORT=8080,NAME=radio
```

Centurion is aimed at repeatable deployments so we don't recommend that you use
this functionality for production deployments. It will work, but it means that
the config is not the whole source of truth for your container configuration.
Caveat emptor.

#### Exporting Environment Variables Locally

Sometimes you need to test how your code works inside the container and you
need to have all of your configuration exported. Centurion includes an action
that will let you do that. It exports all of your environment settings for the
environment you specify. It then partially sanitizes them to preserve things
like `rbenv` settings. Then it executes `/bin/bash` locally.

The action is named `dev:export_only` and you call it like this:

```bash
$ bundle exec centurion -e development -p testing_project -a dev:export_only
$ bundle exec rake spec
```

It's important to note that the second line is actually being invoked with new
environment exported.

Future Additions
----------------

We're currently looking at the following feature additions:

 * [etcd](https://github.com/coreos/etcd) integration for configs and discovery
 * Add the ability to show all the available tasks on the command line

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
 * Add yourself to the CONTRIBUTORS file. I might forget.

If you are simply looking to contribute to the project, taking on one of the
items in the "Future Additions" section above would be a great place to start.
Ping us to let us know you're working on it by opening a GitHub Issue on the
project.

By contributing to this project you agree that you are granting New Relic a
non-exclusive, non-revokable, no-cost license to use the code, algorithms,
patents, and ideas in that code in our products if we so choose. You also agree
the code is provided as-is and you provide no warranties as to its fitness or
correctness for any purpose

Copyright (c) 2014-2015 New Relic, Inc. All rights reserved.
