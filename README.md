# HealthKitTest
Test reading and writing healthkit data on XCode8 - iOS10

This is a prototype project put together to test some HealthKit read/write techniques for migrating a different production project to iOS10 / Swift 3.0

The project tests the following:

-- Getting access to HK
-- Adding new data sample rows to the HK database
-- Reading rows in batch
-- Sensing duplicates
-- Deleting own data from HK on a row-by-row basis

Most of the source files are just boilerplate.  MainTableViewController.swift has all the important and relevant code to the prototype.
