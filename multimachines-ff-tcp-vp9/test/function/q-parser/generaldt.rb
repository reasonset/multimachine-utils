list = []

ARGF.each do |file|
  # General DateTime
  name = File.basename(file.chomp, ".*")
  outfile = if name =~ /(\d{4})[-._: ]?(\d{2})[-._: ]?(\d{2})[-._: ]?(\d{2})[-._: ]?(\d{2})[-._: ]?(\d{2})/
    # To Second
    "#{$1}.#{$2}.#{$3}-#{$4}.#{$5}.#{$6}.webm"
  elsif name =~ /(\d{4})[-._: ]?(\d{2})[-._: ]?(\d{2})[-._: ]?(\d{2})[-._: ]?(\d{2})/
    # To Minute
    "#{$1}.#{$2}.#{$3}-#{$4}.#{$5}-#{$$}.webm"
  else
    # No match. use without filename conversion.
    name + ".webm"
  end

  list.push({
    in: file.chomp,
    out: outfile
  })
end

pp list