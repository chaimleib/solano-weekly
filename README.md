# solano-weekly

Parses 30-day CSV reports and shows the green-ness of each branch.

## Requirements

Ruby 2.2.3

## Usage

1. Run
  ```bash
  $ bundle install
  ```

2. Go to [Solano](https://ci.solanolabs.com/), and get the 30-day CSV reports for every branch you would like to see.
3. Put the CSVs in the `data` directory. No renaming should be necessary.
4. Run
  ```bash
  $ scripts/stat_writer.rb
  ```

5. The output should appear in output/\*.xlsx
