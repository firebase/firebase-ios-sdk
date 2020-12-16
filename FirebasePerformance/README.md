# Firebase Performance

[Firebase Performance](https://firebase.google.com/docs/perf-mon) is a free mobile app performance analytics service. It
provides detailed information about the performance of your apps automatically,
but works at its best with Timers set by you. For more information about app
performance and many other cool mobile services, check out [Firebase](https://firebase.google.com/).

## Prereqs

- `gem install --user cocoapods cocoapods-generate`

## To develop on Firebase Performance

- Run `sh generate_project.sh`

The above command should be sufficient for most scenarios. Few more options listed below.

### Generate project for Prod environment

- `sh generate_project.sh -e "prod"`

### Generate project for Autopush environment

- `sh generate_project.sh` (or) `sh generate_project.sh -e "autopush"`

### Re-generate XCode project by deleting old XCode project

- `sh generate_project.sh -c`
