# solano-weekly

Parses 30-day CSV reports and reports on the green-ness of each branch.

## Spec
For the week of Aug 17th to Aug 22nd, we need to create a solano build failure report. The purpose of the report is to report out for each day of week, per branch

* how many build failures there were, and 
* in total for how long was the build red.

This report should look like the diagram attached.

    build | Date
    ----------------------------------------------------
          | # failures | duration red |
    ----------------------------------------------------
          |            |              |


How we can achieve this is..

1) first we go into solano, https://ci.solanolabs.com/, and download the 30 day history dump for all builds we need. Click on each build, say master, click on the blue Action button, and download the 30 day dump

2) we then write a script to parse through all the build files to generate the report, but we only need it for the last 7 days, not 30
