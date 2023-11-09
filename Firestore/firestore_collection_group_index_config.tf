locals {
  collection_group_indexes = {
    index1 = [
      {
        field_path = "testId"
        order      = "ASCENDING"
      },
      {
        field_path = "a"
        order      = "ASCENDING"
      },
    ]
  }
}