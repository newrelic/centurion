# Copied from ActiveSupport 4.2.1 lib/active_support/core_ext/numeric/bytes.rb
#
# NOTE that THIS LICENSE ONLY APPLIES TO THIS FILE itself, not
# to the rest of the project.
#
# ORIGINAL ACTIVE SUPPORT LICENSE FOLLOWS:
#
# Copyright (c) 2005-2015 David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
begin
  require 'active_support/core_ext/numeric/bytes'
rescue LoadError
  class Numeric
    KILOBYTE = 1024 unless defined? KILOBYTE
    MEGABYTE = KILOBYTE * 1024 unless defined? MEGABYTE
    GIGABYTE = MEGABYTE * 1024 unless defined? GIGABYTE
    TERABYTE = GIGABYTE * 1024 unless defined? TERABYTE
    PETABYTE = TERABYTE * 1024 unless defined? PETABYTE
    EXABYTE  = PETABYTE * 1024 unless defined? EXABYTE

    # Enables the use of byte calculations and declarations, like 45.bytes + 2.6.megabytes
    #
    #   2.bytes # => 2
    def bytes
      self
    end unless method_defined? :bytes
    alias :byte :bytes unless method_defined? :byte

    # Returns the number of bytes equivalent to the kilobytes provided.
    #
    #   2.kilobytes # => 2048
    def kilobytes
      self * KILOBYTE
    end unless method_defined? :kilobytes
    alias :kilobyte :kilobytes unless method_defined? :kilobyte

    # Returns the number of bytes equivalent to the megabytes provided.
    #
    #   2.megabytes # => 2_097_152
    def megabytes
      self * MEGABYTE
    end unless method_defined? :megabytes?
    alias :megabyte :megabytes unless method_defined? :megabyte

    # Returns the number of bytes equivalent to the gigabytes provided.
    #
    #   2.gigabytes # => 2_147_483_648
    def gigabytes
      self * GIGABYTE
    end unless method_defined? :gigabytes
    alias :gigabyte :gigabytes unless method_defined? :gigabyte

    # Returns the number of bytes equivalent to the terabytes provided.
    #
    #   2.terabytes # => 2_199_023_255_552
    def terabytes
      self * TERABYTE
    end unless method_defined? :terabytes
    alias :terabyte :terabytes unless method_defined? :terabyte

    # Returns the number of bytes equivalent to the petabytes provided.
    #
    #   2.petabytes # => 2_251_799_813_685_248
    def petabytes
      self * PETABYTE
    end unless method_defined? :petabytes
    alias :petabyte :petabytes unless method_defined? :petabyte

    # Returns the number of bytes equivalent to the exabytes provided.
    #
    #   2.exabytes # => 2_305_843_009_213_693_952
    def exabytes
      self * EXABYTE
    end unless method_defined? :exabytes
    alias :exabyte :exabytes unless method_defined? :exabyte
  end
end

