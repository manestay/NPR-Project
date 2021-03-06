class IdsToDb
  attr_reader :array

  def initialize(client)
    @client = client
  end

  def parse_file(file_name)
    return @array if @array
    @array = []
    File.open(file_name, 'rb').readlines.each do |line|
      @array.concat(line.split(' '))
    end
    @array
  end

  def write_id(id)
    if Transcript.where(story_id: id).first
      puts "Story #{id} already exists, not modified"
      return
    end

    xml = self.class.parse_xml(id)
    if xml.nil? # no NPRXML for this story
      puts "Story #{id} not found"
      return
    end

    title, date, audio = get_title_date_and_audio_link(id)
    url_link = get_url_link(xml)

    fields = {
      story_id: id,
      title: title,
      date: date,
      url_link: url_link,
      audio_link: audio,
      paragraphs: get_paragraphs(xml)
    }

    puts "Adding story #{id}, title: #{title}"
    Transcript.create(fields)
  end

  def write_ids(ids = @array)
    ids ||= parse_file
    count = 0
    ids.each do |id|
      written = write_id(id)
      count += 1 if written
    end
  ensure
    puts "Added #{count} transcripts to database"
  end

  # class method to return NPRXML in a hash
  def self.parse_xml(id)
    uri = URI.parse("http://api.npr.org/transcript?id=#{id}&apiKey=#{ENV['NPR_API_KEY']}")
    xml_data = Net::HTTP.get_response(uri).body
    Hash.from_xml(xml_data)['transcript']
  end

  protected

  def get_title_date_and_audio_link(id)
    story = @client.query(
      fields: 'title,storyDate,audio',
      id: id
    ).list.stories.first

    title = story.title
    date = story.storyDate
    audio_link = get_audio_link(story.audio)
    Rails.logger.error "Audio not found for #{id}" if audio_link.nil?
    [title, date, audio_link]
  end

  def get_audio_link(audio_array)
    case audio_array.size
    when 0
      return
    when 1
      mp3 = audio_array.first.formats.mp3s.first
      return unless mp3
      mp3.content.sub(/\?.*/, '?dl=1')
    else
      index = audio_array.map(&:type).index('primary')
      return unless index
      mp3 = audio_array[index].formats.mp3s.first
      return unless mp3
      mp3.content.sub(/\?.*/, '?dl=1')
    end
  end

  def get_paragraphs(xml)
    paragraphs = xml['paragraph']
    return paragraphs.map(&:squish) if paragraphs.is_a? Array
    [paragraphs.squish] # only 1 paragraph
  end

  def get_url_link(xml)
    url_link = xml['story']['link'].first
    return url_link unless url_link.is_a? Array
    url_link.first
  end
end
