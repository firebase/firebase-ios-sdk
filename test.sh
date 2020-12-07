    database_files=( "FirebaseDatabase" \
                                             ".github/workflows/.*" \
                                             #"Example/Database/" \
"Interop/Auth/Public/\.\*.h")
          echo "=============== list changed files ==============="
          cat < <(git diff --name-only HEAD^ HEAD)
          echo "========== check paths of changed files ========== ${database_files[@]}"
          git diff --name-only HEAD^ HEAD > files.txt
          echo "::set-output name=database_run_job::false"
          while IFS= read -r file
          do
            echo $file
            for path in "${database_files[@]}"
            do
              echo "$path"
              if [[ "${file}" =~ $path ]]; then 
                echo "This file is  under the directory "
                echo "::set-output name=database_run_job::true"
                break 
              fi
            done
          done < files.txt

