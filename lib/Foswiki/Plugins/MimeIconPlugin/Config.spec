# ---+ Extensions
# ---++ MimeIconPlugin
# This is the configuration used by the <b>MimeIconPlugin</b>.

# **BOOLEAN LABEL="Debug"**
$Foswiki::cfg{Plugins}{MimeIconPlugin}{Debug} = 0;

# **SELECT crystal,oxygen,papirus LABEL="Theme"**
# Icon theme
$Foswiki::cfg{Plugins}{MimeIconPlugin}{Theme} = 'papirus';

# **BOOLEAN LABEL="MemoryCache"**
# Set this to true to enable caching icon mappings in memory in persistent perl enviromnents. 
$Foswiki::cfg{Plugins}{MimeIconPlugin}{MemoryCache} = 1;


1;
