# Encapsules the concept of a position inside a string.
#
class Parslet::Position
  attr_reader :bytepos

  include Comparable

  # charpos may be precomputed by the caller (StringScanner#charpos is
  # O(1)) — deriving it here via byteslice().size is linear in the
  # offset and dominates multibyte-source parse error reporting.
  def initialize(string, bytepos, charpos = nil)
    @string = string
    @bytepos = bytepos
    @charpos = charpos
  end

  def charpos
    @charpos || @string.byteslice(0, @bytepos).size
  end

  def <=>(b)
    bytepos <=> b.bytepos
  end
end
