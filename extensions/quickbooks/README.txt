Interchange + QuickBooks HOWTO
==============================

ic_howto_qb.1.4 (Draft)

1. Introduction
===============

1.1. Summary Description
------------------------

Interchange QuickBooks -- QuickBooks support for transactions and
items

1.2. Audience
-------------

Users who already have Quickbooks setup and are familiar with it, in
addition to having the foundation (or other) catalog correctly
working.

1.3. Contact the author
-----------------------

If you find any spelling errors, technical slip-ups, mistakes,
subliminal messages, or if you wish to send feedback, critique,
remarks, comments, or if you wish to contribute examples, instructions
for alternative platforms, chapters, or other material, please do so.

The preferred method of submitting changes is in the form of a context
diff against the SDF source file (ic_howto_qb.sdf).  Please address
your correspondence to:

Volunteer Maintainer, Dan Browning db@kavod.com

or

Original Author, Mike Heins mike@perusion.com

1.4. Version
------------

This document describes software based on Interchange 4.5 and later.

2. Description
==============

Interchange is a business-to-business and business-to-consumer
internet ordering and cataloguing product. It has the ability to take
orders via the World Wide Web, and store transaction data.

This document describes how to interface Interchange with QuickBooks,
the popular small-business accounting program from Intuit.

QuickBooks has an import/export format called IIF, a mnemonic for
Intuit Interchange Format. Fitting, eh?

The standard capabilities of Interchange allow production of IIF files
for transaction passing.  With some support from Interchange UserTags,
it can even import and export item listings.

3. Contents
===========

The extension files can be found in the Interchange tarball under the
'extensions/quickbooks' directory.  The following files are used with
this extension:

  usertag/import_quicken_items  UserTag for importing items
  usertag/export_quicken_items  UserTag for exporting items
  pages/admin/quickbooks/*      Menu support for Interchange UI
  qb.catalog.cfg                Quickbooks configuration.

4. Installation
===============

To set up this extension, the basic steps are:

o    Create and copy directories and files.

o    Add additional database fields.

o    Modify catalog.cfg with additions.

o    Add "quickbooks" order route to checkout pages.

o    Restart Interchange.

o    Export your items from Interchange catalog (or import your
     existing QuickBooks items to Interchange).

o    Test.

4.1. Terms and locations
------------------------

Several terms are used in the examples.

Catalog Directory

     This is the main directory for the catalog, where catalog.cfg
     resides. It will have a NAME, the name for the catalog. (Some
     common Interchange demo names are foundation, construct, barry,
     and simple.)

     Common locations:

     /var/lib/interchange/NAME /usr/local/interchange/catalogs/NAME
     $HOME/catalogs/NAME

     We will use the path /var/lib/interchange/foundation in these
     examples.

Interchange software directory

     This is the main directory for your Interchange server, where the
     file interchange.cfg resides. Common locations:

     /usr/lib/interchange /usr/local/interchange $HOME/ic

     We will use the path /usr/lib/interchange in these examples.

Interchange tarball directory

     The quickbooks files are located in the untarred distribution
     file, before installation of Interchange is performed.

Interchange User

     The Interchange daemon runs as a user ID that cannot be root. It
     will require write permission on directories it must modify to do
     its work.

     We will use the user ID interch in these examples.

4.2. Create and copy directories and files
------------------------------------------

This extension requires you to add some files to your catalog.

It is assumed you have tools and knowledge to create directories with
the proper permissions. Any directories that will contain varying
files like order transaction logs will require write permission for
the Interchange daemon user; pages and configuration only need have
read permission.

4.3. Quick Installation Script
------------------------------

This script will install the necessary files for you, provided that
you modify the variables to your environment.  Alternately, you can
follow the more detailed installation instructions that follow it.

Note that if you are not using a 4.9.8+ version of Interchange, you
will need to manually install the qb_safe.filter by copying it from
the 4.9.8 code/Filter/qb_safe.filter into your Interchange version.


# Modify these three variables to match your environment.
export QB=/path/to/interchange/extensions/quickbooks
export VENDROOT=/usr/local/interchange
export CATROOT=/home/interch/catalogs/foundation

mkdir -p $CATROOT/include/menus $CATROOT/vars
cp -r $QB/TRANS_QUICKBOOKS \
      $CATROOT/vars
cp -r $QB/pages/admin/quickbooks \
      $CATROOT/pages/admin
cp -i $QB/usertag/* \
      $VENDROOT/code/UI_Tag

# Alternate usertag installation style:
#
#mkdir -p $CATROOT/usertags/global
#cp -i $QB/usertag/* \
#      $CATROOT/usertags/global
#
# Then include the global/*.tag in your interchange.cfg

# Variables that optionally modify the export process, along with
# their help entries.
cat   $QB/products/variable.txt.append >> \
      $CATROOT/products/variable.txt
cat   $QB/products/mv_metadata.asc.append >> \
      $CATROOT/products/mv_metadata.asc

# Menu entries: start with the existing menu, then add ours.
cp -i $VENDROOT/lib/UI/pages/include/menus/Admin.txt \
      $CATROOT/include/menus
cat   $QB/menus/Admin.txt.append >> \
      $CATROOT/include/menus/Admin.txt

# Some configuration changes.
cat >> $CATROOT/catalog.cfg <<EOF
# Allows vars/TRANS_QUICKBOOKS
DirConfig vars
# You can remove these requires if you don't want to use the
# Quickbooks UI menu items
Require usertag import_quicken_items
Require usertag export_quicken_items
EOF


4.4. Admin UI Usage
-------------------

After successful installation, there should be a "Quickbooks" menu
item under the "Admin" category.  From there, you can "generate IIF
files", download them, and perform other Quickbooks-related tasks.

Make orders directory

     Create the directory orders in your Catalog Directory if it
     doesn't already exist. (It may be a symbolic link to another
     location.) It must have write permission on it.

     cd /var/lib/interchange/foundation mkdir orders

     If you are doing this as root, also do:

     chown interch orders

     This directory is used to store the QuickBooks IIF files produced
     for orders. The files are created with the form:

     qbYYYYMMDD.iif

     Each day will have a file, and when a day is complete you should
     download the orders. (There are other schemes possible.)

Copy pages

     You will want the Interchange UI support if you are using the UI.
     It provides links for importing/exporting items, downloading and
     viewing IIF files, and possibly other functions over time. At the
     UNIX command line:

     cd /usr/lib/interchange/ cp -r
     extensions/quickbooks/pages/admin/quickbooks \
     /var/lib/interchange/foundation/pages

Copy report generation file etc/trans_quickbooks

     This file is used to generate the IIF file(s) for transaction
     import into QuickBooks.

     cd /usr/lib/interchange/ cp
     extensions/quickbooks/etc/trans_quickbooks \
     /var/lib/interchange/foundation/etc

Copy usertags

     If you want to use the UI item import/export, two usertags are
     required. The easiest thing is just to copy them to the
     Interchange software directory subdirectory lib/UI/usertag, which
     is #included as a part of the UI configuration file.

     cd /usr/lib/interchange cp -i extensions/quickbooks/usertag/*
     lib/UI/usertag

4.5. Additional database fields -- userdb
-----------------------------------------

If your catalog is not based on a 4.6+ version of the foundation
catalog, you may not have some of the additional database fields
necessary.  If you want the user to retain their customer number, add
the following field to the "userdb" table:

customer_number

It can be an integer number field if your database needs that
information. To add the field in MySQL, you can issue the following
queries at the mysql prompt:

alter table userdb add column customer_number int;

If you don't add it, it just means that a new customer number will be
assigned every time.

WARNING If you are using Interchange DBM files and have live data it
is not recommended you add this field unless you are positive you will
not overwrite your data. If you are not a developer, get one to help
you. In any case, back up your userdb.gdbm or userdb.db file first.

4.6. Additional database fields -- inventory
--------------------------------------------

Quicken also needs an account to debit for the split transactions it
uses to track item sales. If you don't create these fields to relate
to each SKU, the account "Other Income" will be used in the exports.

Add the following fields to the "inventory" table:

account cogs_account

To add the fields in MySQL, you can issue the following queries at the
mysql prompt:

alter table inventory add column account char(20); alter table
inventory add column cogs_account char(20);

Other SQL databases will have similar facilities.

If you are using Interchange DBM files, just export the inventory
database, stop the Interchange server (to prevent corruption), add the
fields on the first line by editing the inventory.txt file, then
restart Interchange.

4.7. Modify catalog.cfg with additions:
---------------------------------------

Add the entries in qb.catalog.cfg to catalog.cfg (you can use an
include statement if you wish).

There are some Require directives to ensure that the needed UserTag
definitions are included in the catalog, as well as the Route which is
used

4.8. Add quickbooks order route
-------------------------------

In the Interchange UI, there is a Preferences area "ORDER_ROUTES". You
should add the quickbooks route. Place it after the transaction
logging step, i.e.

code     ORDER_ROUTES Variable log quickbooks main copy_user

ADVANCED, If you know Interchange Variable settings, you can add it
directly:

Variable ORDER_ROUTES  log quickbooks main copy_user

Also, you can use other methods to set order routes. See the
Interchange reference documentation.

4.9. Additional Variables
-------------------------

Optionally, you may specify some variables that modify the behavior of
the Quickbooks export feature.  Documentation for these variables is
provided via item-specific meta data, which can be added to your
mv_metadata.asc file for automatic display by the Admin UI.

See the installation script at the top of this document for commands
that will append the empty variables to your variable.txt and the help
information to your mv_metadata.asc files.

4.10. Restart the catalog
-------------------------

This can be done by restarting the Interchange server or by clicking
Apply Changes in the UI.

4.11. Export the items
----------------------

You can access the Quickbooks UI index by making your URL:

http://YOURCATALOG_URL/admin/quickbooks/index

It will provide options for importing and exporting items. This is
necessary so QuickBooks will be able to take orders for your items.

QuickBooks uses the product "name" as an SKU, along with an integer
reference number. Either you need to make your SKUs match the integer
reference number, or you must ensure your product title is unique.

4.12. Test
----------

Place a test order on your Interchange catalog once you have finished
installing. You should find a file in the orders directory with the
name qbYYYYMMDD.iif. (YYYY=year, MM=month, DD=day.) Transfer this file
to your QuickBooks machine and run File/Import and select that file as
the source. This should import the customer and order into the system.
If it doesn't work, it may be due to lack of sales tax or shipping
definitions, discussed below.

5. Usage
========

5.1. Accessing Admin UI Features
--------------------------------

A typical installation will cause the Administrative User Interface
Features to become available via the top level menu:

o    Login to the Admin UI

o    Administration

o    Quickbooks

You should then be presented with a menu of the Admin UI features.

5.2. Generating IIF Files
-------------------------

To generate the IIF files, access the corresponding page from the
Admin UI Quickbooks Menu (Administration -> Quickbooks -> Generate IIF
Files).

You will be presented with a query tool.  Select the query options
that you would like and submit your query.  Among the query options,
you have the option to input a QB transaction number.  This will be
the first number that is used when generating the IIF files, and it
will be incremented for each sequential order in the query.

You will be notified of its success or failure.  The resulting page
will:

o    Inform you of the success or failure of the query.

o    Provide a link to the "results" IIF file (which includes all of
     the orders found by the query).  Note that this "results" IIf
     file is overwritten every time a query is run.

o    Provide a link for each IIF file (one per order).  This can be
     used as a backup, or for importing one-by-one instead of all at
     once.

6. Discussion
=============

The interface provided works for the sample company data distributed
with QuickBooks. There are certain requirements to make sure it works
in your environment.

Also, you can change the configuration by editing the file
etc/trans_quickbooks to suit your IIF file needs.

6.1. Sales Tax
--------------

QuickBooks has a taxing system whereby tax rates are defined by
customer location. There is usually also a generic Sales Tax Item,
such as contained in the sample company data. This allows Interchange
to calculate the sales tax. If that item is not present then you will
need to create it, or specify your tax item using the
QB_SALES_TAX_ITEM variable.

6.2. Shipping
-------------

Interchange will add a generic item Shipping to each order that has a
shipping cost. Its MEMO field will contain the text description of the
mode. If that item is not in your QuickBooks item definitions, then
you must create it, or specify your shipping item using the
QB_SHIPPING_ITEM variable.

6.3. Customer Imports
---------------------

To generate a QuickBooks transtype of INVOICE, a CUSTOMER is required.
Interchange outputs a CUST IIF record for each sale with the customer
information. Since QuickBooks uses the customer name or company to
generate the unique listing, we place the Interchange username in
parentheses after the company or name.

6.4. IIF generation at time of order
------------------------------------

As of 4.9, the IIF generation was moved from an order route into the
Admin UI. This was done so that the IIF generation process could be
fine tuned without restarting Interchange and placing an order.  If
you need the IIF file generated at the time of order, you can still
access the pre-4.9.6 files in extensions/quickbooks/legacy.

A. Credits
==========

o    Mike Heins: This document was copied from the original POD
     documentation (extensions/quickbooks/ic_qb.pod) written by Mike
     Heins mike@perusion.com.

o    Dan Browning: Updated by Dan Browning db@kavod.com.

B. Document history
===================

o    July 20, 2002.  Initial revision.

C. Resources
============

C.1. Documentation
------------------

o    What are the IIF File Headers?
     http://www.quickbooks.com/support/faqs/qbw2000/121756.html

o    Also see the Quickbooks Help item, "Reference guide to import
     files"

Copyright 2002 ICDEVGROUP. Freely redistributable under terms of the
GNU General Public License.

