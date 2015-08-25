require_relative './solano_report'

module SolanoStatisticsWriter
  require_relative './solano_report'
  require 'axlsx'

  def self.write_daily_statistics(format: :xlsx, data: {}, ofile: nil)
    dt = data[:start].in_time_zone(data[:tz])
    human_date = dt.strftime("%x (%Z)").gsub('/', '-')
    title = "Solano - Week of #{human_date}"
    puts title

    dates = (0..6).map{|offset| dt + offset.days}
    formatted_dates = dates.map{|d| d.strftime("%A, %x")}

    p = Axlsx::Package.new
    wb = p.workbook
    wb.add_worksheet(name: title) do |sheet|
      # sheet.add_row [nil, "hello"]
      head_style = sheet.styles.add_style(b: true, alignment: {horizontal: :center})
      data_style = sheet.styles.add_style(alignment: {horizontal: :right})
      text_style = sheet.styles.add_style(alignment: {horizontal: :left})

      header1 = formatted_dates.each_with_object([]){|d, ary| ary << d; ary << ''}
      header1.unshift "Build"

      header2 = [
        '# Fail',
        'Red time'
      ]#.map{|s| Axlsx::RichText.new(s, b: true)}
      header2 *= 7
      header2.unshift nil

      sheet.add_row header1, style: [head_style]*15
      sheet.add_row header2, style: [head_style]*15

      letters = ('A'..'Z').to_a
      (0..6).each do |day|
        sheet.merge_cells("#{letters[1 + 2*day]}1:#{letters[2 + 2*day]}1")
      end
      sheet.merge_cells("A1:A2")

      branches = data[:report].map(&:branch).uniq.sort
      branches.each do |branch|
        row = [branch]

        dates.each do |dt|
          day_stats = (
            data[:stats][dt] && data[:stats][dt][branch] || 
            {fail_count: 0, red_time: 0.days}
          )
          fail_count = day_stats[:fail_count] || 0
          red_time = humanize_duration(day_stats[:red_time] || 0.days)
          row << fail_count
          row << red_time
        end

        sheet.add_row row, style: [text_style, *[data_style]*14]
      end

      sheet.column_widths 18, *[7, 13]*7
    end
    p.use_shared_strings = true
    p.serialize ofile
  end

  def self.humanize_duration(d)
    total_seconds = d.to_f.round
    seconds = total_seconds % 60
    minutes = (total_seconds/60) % 60
    hours = (total_seconds/3600) 
    format("%02d:%02d:%02d", hours, minutes, seconds)
  end
end
