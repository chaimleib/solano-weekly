require 'net/http'
require 'selenium-webdriver'
require 'pry'

class SolanoReportEmailer
  attr_reader :host
  attr_reader :path
  attr :driver

  # currently, Solano only emails the CSV reports
  def initialize(user, password)
    @user = user
    @password = password
    @path = '/api/v2/session_history/csv_export'
    @host = URI.parse('https://ci.solanolabs.com')
    @driver = Selenium::WebDriver.for :chrome

  end

  def url
    @host + @path
  end

  def fetch_ids_matching_branch_name(url)
    rgx = /^([0-9]{3}(_[0-9]+){0,2}_release|master)$/

    # req = Net::HTTP::Get.new(url.to_s)
    # req.basic_auth(@user, @password)
    # dashboard = Net::HTTP.start(url.host, url.port) {|http|
    #   http.request(req)
    # }
  end

  def wait_to_leave_page
    old_url = URI.parse(@driver.current_url)
    wait = Selenium::WebDriver::Wait.new(timeout: 20)
    wait.until{ URI.parse(@driver.current_url) != old_url }
  end

  def wait_for_page_load
    wait = Selenium::WebDriver::Wait.new(timeout: 20)
    wait.until {
      @driver.execute_script("return document.readyState;") == "complete"
    }
  end

  def login
    @driver.navigate.to @host
    user_field = @driver[name: 'user[email]']
    pass_field = @driver[name: 'user[password]']
    submit_btn = @driver[tag_name: 'input', type: 'submit']

    user_field.send_keys @user
    pass_field.send_keys @password + "\n"

    wait_to_leave_page
  end

  def email_all_csvs
    urls = scrape_branch_links
    urls.values.each{ |url| email_csv(url) }
  end

  def scrape_branch_links(rgx = /^([0-9]{3}(_[0-9]+){0,2}_release|master)$/)
    wait_for_page_load

    # make sure we are at the dashboard
    unless URI.parse(@driver.current_url) == @host
      raise "Not on Solano Dashboard page"
    end

    links = @driver.find_elements css:'section.branch-info header a'

    filtered_links = links.select{|b| b.text =~ rgx}
    urls = filtered_links.each_with_object({}) {|b,h|
      h[b.text] = URI.parse b['href']
    }
  end

  def email_csv(branch_url)
    # exportSessionCSV: function(e) {
    #     var t = this,
    #         s = $(e.target);
    #     t.disableExport || (t.disableExport = !0, setTimeout(function() {
    #         t.disableExport = !1
    #     }, 3e4), $.ajax({
    #         type: "POST",
    #         url: "/api/v2/session_history/csv_export",
    #         dataType: "JSON",
    #         data: {
    #             days: s.data("days"),
    #             id: t.sessionHistory.relatedSessionId
    #         }
    #     }).done(function(e) {
    #         SolanoCI.Main.helpers.updateFlash(e.success, "success")
    #     }).fail(function(e) {
    #         SolanoCI.Main.helpers.updateFlash(JSON.parse(e.responseText).explanation, "error")
    #     }))
    # },
    session_id = branch_url.path.split('/').last
    req_data = JSON.dump({days: '30', id: session_id})
    @driver.execute_script <<-JSPOST
      $.ajax({
        type: 'POST',
        url: '/api/v2/session_history/csv_export',
        dataType: 'JSON',
        data: #{req_data}
      });
    JSPOST
  end
end
