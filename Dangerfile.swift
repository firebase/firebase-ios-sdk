import Danger

let danger = Danger()

let hasChanges = !(danger.git.createdFiles + danger.git.modifiedFiles).isEmpty

if hasChanges {
  message("Has changes")
}
