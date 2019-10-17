### Helper functions

# Determine if any of the files were changed or deleted.
# Taken from samdmarshall/danger
def didModify(files_array)
  files_array.each do |file_name|
    if git.modified_files.include?(file_name) || git.deleted_files.include?(file_name)
      return true
    end
  end
  return false
end

# Determine if there are changes in files matching any of the
# path patterns provided.
def hasChangesIn(paths)
  path_array = Array(paths)
  path_array.each do |dir|
    if !git.modified_files.grep(dir).empty?
      return true
    end
  end
  return false
end

# Adds the provided labels to the current PR.
def addLabels(label_array)
  issue_number = github.pr_json["number"]
  repo_name = "firebase/firebase-ios-sdk"
  github.api.add_labels_to_an_issue(repo_name, issue_number, label_array)
end

# Returns a list of all labels for a given PR. PRs that touch
# multiple directories may have multiple labels.
def labelsForModifiedFiles()
  labels = []
  labels.append("api: abtesting") if @has_abtesting_changes
  labels.append("api: auth") if @has_auth_changes
  labels.append("api: core") if @has_core_changes
  labels.append("api: database") if @has_database_changes
  labels.append("api: dynamiclinks") if @has_dynamiclinks_changes
  labels.append("api: firestore") if @has_firestore_changes
  labels.append("api: functions") if @has_functions_changes
  labels.append("api: inappmessaging") if @has_inappmessaging_changes
  labels.append("api: installations") if @has_installations_changes
  labels.append("api: instanceid") if @has_instanceid_changes
  labels.append("api: messaging") if @has_messaging_changes
  labels.append("api: remoteconfig") if @has_remoteconfig_changes
  labels.append("api: storage") if @has_storage_changes
  labels.append("GoogleDataTransport") if @has_gdt_changes
  labels.append("GoogleUtilities") if @has_googleutilities_changes
  labels.append("zip-builder") if @has_zipbuilder_changes
  return labels
end

### Definitions

# Label for any change that shouldn't have an accompanying CHANGELOG entry,
# including all changes that do not affect the compiled binary (i.e. script
# changes, test-only changes)
declared_trivial = github.pr_body.include? "#no-changelog"

# Whether or not there are pending changes to any changelog file.
has_changelog_changes = hasChangesIn(["CHANGELOG"])

# Whether or not the LICENSE file has been modified or deleted.
has_license_changes = didModify(["LICENSE"])

## Product directories
@has_abtesting_changes = hasChangesIn("FirebaseABTesting/")
@has_auth_changes = hasChangesIn("Firebase/Auth")
@has_core_changes = hasChangesIn([
  "Firebase/Core/",
  "Firebase/CoreDiagnostics/",
  "CoreOnly/"])
@has_database_changes = hasChangesIn("Firebase/Database/")
@has_dynamiclinks_changes = hasChangesIn("Firebase/DynamicLinks/")
@has_firestore_changes = hasChangesIn("Firestore/")
@has_functions_changes = hasChangesIn("Functions/")
@has_inappmessaging_changes = hasChangesIn([
  "Firebase/InAppMessaging/",
  "Firebase/InAppMessagingDisplay/",
  "InAppMessaging/Example/",
  "InAppMessagingDisplay/"])
@has_installations_changes = hasChangesIn("FirebaseInstallations/Source/")
@has_instanceid_changes = hasChangesIn("Firebase/InstanceID/")
@has_messaging_changes = hasChangesIn("Firebase/Messaging/")
@has_remoteconfig_changes = hasChangesIn("FirebaseRemoteConfig/")
@has_storage_changes = hasChangesIn("Firebase/Storage/")

@has_gdt_changes = hasChangesIn("GoogleDataTransport/") ||
  hasChangesIn("GoogleDataTransportCCTSupport")
@has_googleutilities_changes = hasChangesIn("GoogleUtilities/")
@has_zipbuilder_changes = hasChangesIn("ZipBuilder/")

### Actions

# Warn if a changelog is left out on a non-trivial PR
if !has_changelog_changes && !declared_trivial
  warn("Did you forget to add a changelog entry? (Add `#no-changelog` to the PR description to silence this warning.)")
end

# Error on license edits
fail("LICENSE changes are explicitly disallowed.") if has_license_changes

# Label PRs based on diff files
suggested_labels = labelsForModifiedFiles()
if !suggested_labels.empty?
  addLabels(suggested_labels)
end
