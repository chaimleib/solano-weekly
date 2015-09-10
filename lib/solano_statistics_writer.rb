require_relative './solano_report'

module SolanoStatisticsWriter
  require_relative './solano_report'
  require 'axlsx'

  def self.write_fail_times(data: {}, ofile: nil)
    ## Preformatting
    meta = data[:meta]
    dt = meta[:start].in_time_zone(meta[:tz])
    human_date = dt.strftime("%x (%Z)").gsub('/', '-')
    duration = meta[:duration]

    title = "Solano - Week of #{human_date}"
    puts title

    by_branch = data[:by_branch]

    p = Axlsx::Package.new
    wb = p.workbook

    by_branch.keys.sort.each do |branch|
      ## Add worksheet
      wb.add_worksheet(name: "#{branch} Failures") do |sheet|
        # Styles
        head_style = sheet.styles.add_style(b: true, alignment: {horizontal: :center})
        data_style = sheet.styles.add_style(alignment: {horizontal: :right})
        text_style = sheet.styles.add_style(alignment: {horizontal: :left})
        
        # Header
        sheet.add_row ["Id", "Failed at", "Until", "Duration"], style: [head_style]*4

        # Data rows
        failures = by_branch[branch]
        if failures.empty?
          sheet.add_row ['No failures'], style: [text_style]
          next
        end
        failures.each do |fail|
          if fail[:duration].nil?
            fail_stop =  '--'
            fail_duration = '--'
          else
            fail_stop = fail[:start] + fail[:duration]
            fail_duration = self.humanize_duration(fail[:duration])
          end
          duration
          sheet.add_row [
            fail[:id],
            fail[:start].to_s,
            fail_stop.to_s,
            fail_duration
          ], style: [data_style]*4
        end
      end
    end

    self.meta_sheet(wb, meta)

    ## Serialize
    p.use_shared_strings = true  # for Apple Numbers xlsx import
    p.serialize ofile
    puts "  => #{ofile}"
  end

  def self.write_daily_statistics(data: {}, ofile: nil)
    ## Preformatting
    meta = data[:meta]
    dt = meta[:start].in_time_zone(meta[:tz])
    human_date = dt.strftime("%x (%Z)").gsub('/', '-')
    duration = meta[:duration]
    last_day_offset = (duration - 1.day)/1.day
    dates = (0..last_day_offset).map{|offset| dt + offset.days}
    formatted_dates = dates.map{|d| d.strftime("%A, %x")}

    title = "Solano - Week of #{human_date}"
    puts title

    by_branch = data[:by_branch]

    ## XLSX layout
    p = Axlsx::Package.new
    wb = p.workbook
    wb.add_worksheet(name: title) do |sheet|
      ## Header rows
      head_style = sheet.styles.add_style(b: true, alignment: {horizontal: :center})
      data_style = sheet.styles.add_style(alignment: {horizontal: :right})
      text_style = sheet.styles.add_style(alignment: {horizontal: :left})

      header1 = formatted_dates.each_with_object([]){|d, ary| ary << d; ary << ''}
      header1.unshift "Branch"

      header2 = ['# Fail', 'Red time']*7
      header2.unshift nil

      sheet.add_row header1, style: [head_style]*15
      sheet.add_row header2, style: [head_style]*15

      letters = ('A'..'Z').to_a
      (0..last_day_offset).each do |day|
        sheet.merge_cells("#{letters[1 + 2*day]}1:#{letters[2 + 2*day]}1")
      end
      sheet.merge_cells("A1:A2")

      ## Data rows
      by_branch.sort.each do |branch, by_date|
        row = [branch]

        dates.each do |dt|
          day_stats = by_date[dt] || {fail_count: 0, red_time: 0.days}
          fail_count = day_stats[:fail_count] || 0
          red_time = humanize_duration(day_stats[:red_time] || 0.days)
          row << fail_count
          row << red_time
        end

        sheet.add_row row, style: [text_style, *[data_style]*14]
      end

      ## Final tidy
      sheet.column_widths 18, *[7, 13]*7
    end

    self.meta_sheet(wb, meta)

    ## Serialize
    p.use_shared_strings = true  # for Apple Numbers xlsx import
    p.serialize ofile
    puts "  => #{ofile}"
  end

  def self.meta_sheet(wb, meta)
    wb.add_worksheet(name: "Meta") do |sheet|
      key_style = sheet.styles.add_style(b: true)
      meta.merge!({
        created_on: Time.now.in_time_zone(meta[:tz]),
      })
      meta.each do |k, v|
        if v.is_a? ActiveSupport::Duration
          v = "#{v/1.day}.days"
        elsif v.is_a? Array
          v = v.join("\n")
        end
        sheet.add_row [k.to_s, v.to_s], style: [key_style, nil]
      end
    end
  end

  def self.humanize_duration(d)
    total_seconds = (d / 1.second).to_f.round
    seconds = total_seconds % 60
    minutes = (total_seconds/60) % 60
    hours = (total_seconds/3600) 
    format("%02d:%02d:%02d", hours, minutes, seconds)
  end
end
