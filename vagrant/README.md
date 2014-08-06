Vagrant Usage
=========

The vagrant setup deploys a fleet of Docker servers ready for Centurion to deploy into.

## Requirements

* [VirtualBox](https://www.virtualbox.org/wiki/Downloads) 4.2+
* [Vagrant](https://www.vagrantup.com/downloads.html) 1.6+

## Quick Start

1. [Install VirtualBox](https://www.virtualbox.org/wiki/Downloads)

1. [Install Vagrant](http://www.vagrantup.com/downloads.html)

1. Clone this repository

Usage
---------

By default, it is setup to create 3 Docker server instances.  It is installing the latest Docker version onto Ubuntu Trusty (14.04).  You can change that value in the "Vagrantfile" at the root of this project

     $num_instances = 3

# Starting Vagrant instances

At the root of this project start up the Vagrant instances

    vagrant up

It will do a bunch of stuff and after the command prompt returns to you you can view the instances with this command:

    vagrant status

At this point you can follow the instructions on how to use Centurion against this fleet of Docker server.