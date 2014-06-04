# This file borrows heavily from the Capistrano project, so although much of
# the code has been re-written at this point, we include their license here
# as a reminder. NOTE that THIS LICENSE ONLY APPLIES TO THIS FILE itself, not
# to the rest of the project.
#
# ORIGINAL CAPISTRANO LICENSE FOLLOWS:
#
# MIT License (MIT)
# 
# Copyright (c) 2012-2013 Tom Clements, Lee Hambley
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'singleton'

module Capistrano
  module DSL
    module Env
      class CurrentEnvironmentNotSetError < RuntimeError; end

      class Store < Hash
        include Singleton
      end

      def env
        Store.instance
      end

      def fetch(key, default=nil, &block)
        env[current_environment][key] || default
      end

      def any?(key)
        value = fetch(key)
        if value && value.respond_to?(:any?)
          value.any?
        else
          !fetch(key).nil?
        end
      end

      def set(key, value)
        env[current_environment][key] = value
      end

      def delete(key)
        env[current_environment].delete(key)
      end

      def set_current_environment(environment)
        env[:current_environment] = environment
        env[environment] ||= {}
      end

      def current_environment
        raise CurrentEnvironmentNotSetError.new('Must set current environment') unless env[:current_environment]
        env[:current_environment]
      end

      def clear_env
        env.clear
      end
    end
  end
end

module Capistrano
  module DSL
    include Env

    def invoke(task, *args)
      Rake::Task[task].invoke(*args)
    end
  end
end
