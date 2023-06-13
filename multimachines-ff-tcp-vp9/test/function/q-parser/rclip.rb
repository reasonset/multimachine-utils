list = []
@config = {
  "this" => {
    "title" => "TEST",
    "prefix" => "TEST-rclip"
  }
}

def calc_size size
  100000000
end

ARGF.each do |i|
  source_file, ss, t, song, difficulty, tags = *i.chomp.split("\t", 6)

  ss = nil if ss == "-"
  t = nil if t == "-"
  ff_clip = {}
  ff_clip["ss"] = ss
  ff_clip["to"] = t
  # If ss or to given, set 10 to size to be ignored. Otherwise set size.
  size = (ss or t) ? 10 : calc_size(source_file)

  name = File.basename(source_file, ".*")
  date = (name =~ /(\d{4})[-._: ]?(\d{2})[-._: ]?(\d{2})/ ? "#{$1}.#{$2}.#{$3}" : "")
  outfile = [song, difficulty, date, tags].join("-")

  list.push({
            file: source_file,
            outfile: (outfile + ".webm"),
            source_prefix: @config["this"]["prefix"],
            title: @config["this"]["title"],
            original_size: 100000000,
            size: size,
            ff_options: (@config["this"]["ff_options"] || {}).merge(ff_clip)
          })
end

pp list