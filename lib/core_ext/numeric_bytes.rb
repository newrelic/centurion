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

class Numeric
  KILOBYTE = 1024
  MEGABYTE = KILOBYTE * 1024
  GIGABYTE = MEGABYTE * 1024
  TERABYTE = GIGABYTE * 1024
  PETABYTE = TERABYTE * 1024
  EXABYTE  = PETABYTE * 1024

  # Enables the use of byte calculations and declarations, like 45.bytes + 2.6.megabytes
  #
  #   2.bytes # => 2
  def bytes
    self
  end
  alias :byte :bytes

  # Returns the number of bytes equivalent to the kilobytes provided.
  #
  #   2.kilobytes # => 2048
  def kilobytes
    self * KILOBYTE
  end
  alias :kilobyte :kilobytes

  # Returns the number of bytes equivalent to the megabytes provided.
  #
  #   2.megabytes # => 2_097_152
  def megabytes
    self * MEGABYTE
  end
  alias :megabyte :megabytes

  # Returns the number of bytes equivalent to the gigabytes provided.
  #
  #   2.gigabytes # => 2_147_483_648
  def gigabytes
    self * GIGABYTE
  end
  alias :gigabyte :gigabytes

  # Returns the number of bytes equivalent to the terabytes provided.
  #
  #   2.terabytes # => 2_199_023_255_552
  def terabytes
    self * TERABYTE
  end
  alias :terabyte :terabytes

  # Returns the number of bytes equivalent to the petabytes provided.
  #
  #   2.petabytes # => 2_251_799_813_685_248
  def petabytes
    self * PETABYTE
  end
  alias :petabyte :petabytes

  # Returns the number of bytes equivalent to the exabytes provided.
  #
  #   2.exabytes # => 2_305_843_009_213_693_952
  def exabytes
    self * EXABYTE
  end
  alias :exabyte :exabytes
end
