locals {
  indexes = {
    index1 = [
      {
        field_path = "b"
        order      = "ASCENDING"
      },
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "a"
        order      = "ASCENDING"
      },
    ]
    index2 = [
      {
        field_path = "a"
        order      = "ASCENDING"
      },
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "b"
        order      = "DESCENDING"
      },
    ]
    index3 = [
      {
        field_path = "a"
        order      = "ASCENDING"
      },
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "b"
        order      = "ASCENDING"
      },
    ]
    index4 = [
      {
        field_path = "a"
        order      = "ASCENDING"
      },
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "a"
        order      = "DESCENDING"
      },
    ]
    index5 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "a"
        order      = "ASCENDING"
      },
    ]
    index6 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "b"
        order      = "ASCENDING"
      },
    ]
    index7 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "b"
        order      = "DESCENDING"
      },
    ]
    index8 = [
      {
        field_path = "b"
        order      = "ASCENDING"
      },
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "a"
        order      = "DESCENDING"
      },
    ]
  }
}
