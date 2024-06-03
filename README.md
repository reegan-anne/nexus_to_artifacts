# nexus_to_artifacts
Here is a bash script that migrates all maven packages from an on-prem or cloud instance of Sonatype Nexus to an Azure Artifacts feed.

What you will need:
1. Login details to your Sonatype Nexus instance
2. Minimum Contributor rights to your Azure Artifacts Feed
3. Your local settings.xml file with valid credentials for your Azure Artifacts feed

How to use?
1. Clone this repo
2. Edit the script of your choice with your details (shown with the comments with an example) specifically your nexus instance and your repo name
3. Run the script of your choice in the terminal!