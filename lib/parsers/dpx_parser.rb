class FormatParser::DPXParser
  FILE_INFO = [
    :x4,   # magic bytes SDPX
    :x4,   # u32  :image_offset,   :desc => 'Offset to image data in bytes', :req => true
    :x8,   # char :version, 8,     :desc => 'Version of header format', :req => true
    :x4,   # u32  :file_size,      :desc => "Total image size in bytes", :req => true
    :x4,   # u32  :ditto_key,      :desc => 'Whether the basic headers stay the same through the sequence (1 means they do)'
    :x4,   # u32  :generic_size,   :desc => 'Generic header length'
    :x4,   # u32  :industry_size,  :desc => 'Industry header length'
    :x4,   # u32  :user_size,      :desc => 'User header length'
    :x100, # char :filename, 100,  :desc => 'Original filename'
    :x24,  # char :timestamp, 24,  :desc => 'Creation timestamp'
    :x100, # char :creator, 100,   :desc => 'Creator application'
    :x200, # char :project, 200,   :desc => 'Project name'
    :x200, # char :copyright, 200, :desc => 'Copyright'
    :x4,   # u32  :encrypt_key,   :desc => 'Encryption key'
    :x104,  # blanking :reserve, 104
  ].join

  FILM_INFO = [
    :x2, # char :id, 2,          :desc => 'Film mfg. ID code (2 digits from film edge code)'
    :x2, # char :type, 2,        :desc => 'Film type (2 digits from film edge code)'
    :x2, # char :offset, 2,      :desc => 'Offset in perfs (2 digits from film edge code)'
    :x6, # char :prefix, 6,      :desc => 'Prefix (6 digits from film edge code'
    :x4, # char :count, 4,       :desc => 'Count (4 digits from film edge code)'
    :x32,# char :format, 32,     :desc => 'Format (e.g. Academy)'
    :x4, # u32 :frame_position,  :desc => 'Frame position in sequence'
    :x4, # u32 :sequence_extent, :desc => 'Sequence length'
    :x4, # u32 :held_count,      :desc => 'For how many frames the frame is held'
    :x4, # r32 :frame_rate,      :desc => 'Frame rate'
    :x4, # r32 :shutter_angle,   :desc => 'Shutter angle'
    :x4, # char :frame_id, 32,   :desc => 'Frame identification (keyframe)' 
    :x4, # char :slate, 100,     :desc => 'Slate information'
    :x4, # blanking :reserve, 56
  ].join

  IMAGE_ELEMENT = [
    :x4, # u32 :data_sign, :desc => 'Data sign (0=unsigned, 1=signed). Core is unsigned', :req => true
    # 
    :x4, # u32 :low_data,      :desc => 'Reference low data code value'
    :x4, # r32 :low_quantity,  :desc => 'Reference low quantity represented'
    :x4, # u32 :high_data,     :desc => 'Reference high data code value (1023 for 10bit per channel)'
    :x4, # r32 :high_quantity, :desc => 'Reference high quantity represented'
    # 
    # # TODO: Autoreplace with enum values. 
    :x1, # u8 :descriptor,   :desc => 'Descriptor for this image element (ie Video or Film), by enum', :req => true
    :x1, # u8 :transfer,     :desc => 'Transfer function (ie Linear), by enum', :req => true
    :x1, # u8 :colorimetric, :desc => 'Colorimetric (ie YcbCr), by enum', :req => true
    :x1, # u8 :bit_size,     :desc => 'Bit size for element (ie 10)', :req => true
    # 
    :x2, # u16 :packing,     :desc => 'Packing (0=Packed into 32-bit words, 1=Filled to 32-bit words))', :req => true
    :x2, # u16 :encoding,    :desc => "Encoding (0=None, 1=RLE)", :req => true
    :x4, # u32 :data_offset, :desc => 'Offset to data for this image element', :req => true
    :x4, # u32 :end_of_line_padding, :desc => "End-of-line padding for this image element"
    :x4, # u32 :end_of_image_padding, :desc => "End-of-line padding for this image element"
    :x32,# char :description, 32
  ].join

  IMAGE_INFO = [
    :x2, # u16 :orientation, OrientationInfo,    :desc => 'Orientation descriptor',    :req => true
    :n1, # u16 :number_elements,                   :desc => 'How many elements to scan', :req => true
    :N1, # u32 :pixels_per_line,                   :desc => 'Pixels per horizontal line', :req => true
    :N1, # u32 :lines_per_element,                 :desc => 'Line count', :req => true
    IMAGE_ELEMENT * 8, # 8 IMAGE_ELEMENT structures
    :x52, # blanking :reserve, 52
  ].join

  ORIENTATION_INFO = [
    :x4, #  u32 :x_offset
    :x4, #  u32 :y_offset
    #
    :x4, #  r32 :x_center
    :x4, #  r32 :y_center
    #
    :x4, #  u32 :x_size, :desc => 'Original X size'
    :x4, #  u32 :y_size, :desc => 'Original Y size'
    #  
    :x100, #  char :filename, 100, :desc => "Source image filename"
    :x24,  #  char :timestamp, 24, :desc => "Source image/tape timestamp"
    :x32,  #  char :device,    32, :desc => "Input device or tape"
    :x32,  #  char :serial,    32, :desc => "Input device serial number"
    #
    :x4,   #  array :border, :u16, 4, :desc => 'Border validity: XL, XR, YT, YB'
    :x4,
    :x4,
    :x4,

    :x4,   #  array :aspect_ratio , :u32, 2, :desc => "Aspect (H:V)"
    :x4,
    #
    :x28,  #  blanking :reserve, 28
  ].join

  DPX_INFO = [
    FILE_INFO,
    IMAGE_INFO,
    ORIENTATION_INFO,
  ].join

  SIZEOF = ->(pattern) {
    bytes_per_element = {
      "v" => 2, # 16bit uints
      "n" => 2,
      "V" => 4, # 32bit uints
      "N" => 4,
      "C" => 1,
      "x" => 1,
    }
    pattern.scan(/[^\d]\d+/).map do |pattern|
      unpack_code = pattern[0]
      num_repetitions = pattern[1..-1].to_i
      bytes_per_element.fetch(unpack_code) * num_repetitions
    end.inject(&:+)
  }

  BE_MAGIC = 'SDPX'
  LE_MAGIC = BE_MAGIC.reverse

  READ_SIZE = SIZEOF[DPX_INFO]
  def make_le(pattern)
    pattern.tr("n", "v").tr("N", "V")
  end

  def information_from_io(io)
    io.seek(0)
    magic = io.read(4)
    is_le = false

    if magic == BE_MAGIC
      is_le = false
    elsif magic == LE_MAGIC
      is_le = true
    else
      return nil
    end
    io.seek(0) # Our pattern includes the magic bytes

    pattern = is_le ? make_le(DPX_INFO) : DPX_INFO
    header_blob = io.read(READ_SIZE)
    num_elements, pixels_per_line, num_lines, *rest = header_blob.unpack(pattern)
    FormatParser::FileInformation.new(width_px: pixels_per_line, height_px: num_lines)
  end
end