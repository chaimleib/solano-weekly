#!/usr/bin/env ruby
require 'pry'
require_relative '../lib/natural_sort'
require 'awesome_print'

include NaturalSort

p NaturalSort.natural_sort %W(aa a aaa)
p NaturalSort.natural_sort %W(9 10 11)
p NaturalSort.natural_sort %W(file9 file10 file11)
p NaturalSort.natural_sort %W(file2c file2b file1 file2)
p NaturalSort.natural_sort %W(a _a aa _aa __a __aa)
p NaturalSort.natural_sort %W(a 2 _)

versions = %W(
  2.0.1
  2.0b
  10.1
  10.0
  10.0.2
  03.2.1
  10.0.2a
  10.0.2a3
  10.0.2a10
  20.0.0
)
p NaturalSort.natural_sort versions
p NaturalSort.version_sort versions

branches = %W(
  013_release
  012_release
  012_0_1_release
  012_0_2_release
  012_0_15_release
  _master1
  _master2
  _master1a
  master
)
p NaturalSort.natural_sort branches
p NaturalSort.version_sort branches
