maestro-svn-plugin
====================

A Maestro Plugin that allows execution of subversion commands

Task
----

/svn/checkout

Task Parameters
---------------

* "Path"

  The location on disk to store the cloned repository

* "URL"

  URL to be passed to svn as parameter to "svn checkout $URL"

* "Options"

  Default: ""

  SVN Options

* "Clean Working Copy"

  Default: false

  If "true" will delete the working directory (Path) and force a "git clone" to be performed, otherwise existing repository will be updated with "git pull" (if present)

* "Force Build"

  Default: false

  Determines what the composition will do if the repository has already been cloned and no new changes have been detected.
  true: Will allow composition to continue and perform normal build process
  false: Composition will stop
  
  Note: This field is set to 'true' when a composition is manually started, and left at 'false' if the composition starts due to an external trigger (i.e. a commit notification from a git server)

Task
----

/svn/copy

Task Parameters
---------------

* "Source"

  Path to the source working copy (file or url)

* "Revision" (optional)

  The revision number to copy

* "Destination"

  Repository location for copy

* "Message"

  Commit message

* "Options"

  SVN Options

