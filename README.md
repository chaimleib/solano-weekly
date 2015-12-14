# solano-weekly

Parses 30-day CSV reports and shows the green-ness of each branch.

## Email test

This email branch is to test automating the sending of the CSV reports (step 2 below). Currently, master requires you to tediously click a bunch of stuff. This branch aims to make this bit easier.

Current progress is in `lib/solano_report_emailer.rb` and `scripts/emailer.rb`.

## Requirements

Ruby 2.2.3

## Usage

1. Run
  ```bash
  $ bundle install
  ```

2. Put your Solano login info into config.yml and then run
  ```bash
  $ scripts/emailer.rb
  ```
3. Take the CSVs just emailed to you and put them in the `data` directory. No renaming should be necessary.
4. Run
  ```bash
  $ scripts/stat_writer.rb
  ```

5. The output should appear in output/\*.xlsx

