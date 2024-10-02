# Firebase Performance Monitoring

[Firebase Performance Monitoring](https://firebase.google.com/docs/perf-mon) is a free mobile app performance analytics service. It
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

### Generate project for Autopush environment. The events generated for the Autopush environment will not be available on the console outside of Google as these are processed on our staging servers.

- `sh generate_project.sh` (or) `sh generate_project.sh -e "autopush"`

### Re-generate Xcode project by deleting old Xcode project

- `sh generate_project.sh -c`
