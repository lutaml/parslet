
# Encapsules the concept of a position inside a string.
#
class Parslet::Position
  attr_reader :bytepos

  include Comparable

  def initialize(string, bytepos, charpos)
    @string = string
    @bytepos = bytepos
    @charpos = charpos
  end

  def charpos
    # If charpos was provided during initialization, use it
    return @charpos if @charpos

    # Cache the calculated charpos to avoid repeated calculations
    @charpos ||= calculate_charpos
  end

  private

  def calculate_charpos
    # Calculate it based on platform
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'opal'
      # In Opal, convert byte position to character position.
      # We need to calculate how many characters occupy the first @bytepos bytes.
      %x{
        var str = #{@string};
        var bytePos = #{@bytepos};
        var chars = Array.from(str);
        var byteCount = 0;
        var charCount = 0;

        for (var i = 0; i < chars.length; i++) {
          if (byteCount >= bytePos) break;

          var char = chars[i];
          var codePoint = char.codePointAt(0);

          // Calculate UTF-8 byte length for this character
          if (codePoint < 0x80) {
            byteCount += 1;
          } else if (codePoint < 0x800) {
            byteCount += 2;
          } else if (codePoint < 0x10000) {
            byteCount += 3;
          } else {
            byteCount += 4;
          }

          if (byteCount <= bytePos) {
            charCount++;
          }
        }

        return charCount;
      }
    else
      # Ruby: Use standard byteslice which handles Unicode correctly
      @string.byteslice(0, @bytepos).size
    end
  end

  public

  def <=>(b)
    bytepos <=> b.bytepos
  end
end
