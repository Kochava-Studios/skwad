import Foundation

/// Test fixtures for git command output parsing
enum GitOutputFixtures {

    // MARK: - Status Output Fixtures

    static let emptyStatus = ""

    static let branchInfoOnly = """
# branch.head main
# branch.upstream origin/main
# branch.ab +2 -1
"""

    static let branchNoUpstream = """
# branch.head feature/test
"""

    static let modifiedStaged = """
# branch.head main
1 M. N... 100644 100644 100644 abc123 def456 file.swift
"""

    static let modifiedUnstaged = """
# branch.head main
1 .M N... 100644 100644 100644 abc123 def456 file.swift
"""

    static let modifiedBoth = """
# branch.head main
1 MM N... 100644 100644 100644 abc123 def456 file.swift
"""

    static let addedFile = """
# branch.head main
1 A. N... 000000 100644 100644 000000 abc123 newfile.swift
"""

    static let deletedFile = """
# branch.head main
1 D. N... 100644 000000 000000 abc123 000000 removed.swift
"""

    static let renamedFile = "# branch.head main\n2 R. N... 100644 100644 100644 abc123 def456 R100 new.swift\told.swift"

    static let copiedFile = "# branch.head main\n2 C. N... 100644 100644 100644 abc123 def456 C100 copied.swift\toriginal.swift"

    static let untrackedFile = """
# branch.head main
? untracked.txt
"""

    static let unmergedFile = """
# branch.head main
u UU N... 100644 100644 100644 100644 abc123 def456 ghi789 conflicted.swift
"""

    static let multipleFiles = """
# branch.head feature/test
# branch.upstream origin/feature/test
# branch.ab +1 -0
1 M. N... 100644 100644 100644 abc123 def456 src/Model.swift
1 .M N... 100644 100644 100644 abc123 def456 src/View.swift
1 A. N... 000000 100644 100644 000000 abc123 src/NewFile.swift
? README.md
"""

    static let pathWithSpaces = """
# branch.head main
1 M. N... 100644 100644 100644 abc123 def456 path/with spaces/file.swift
"""

    static let unicodePath = """
# branch.head main
1 M. N... 100644 100644 100644 abc123 def456 src/emoji_test.swift
"""

    // MARK: - Diff Output Fixtures

    static let emptyDiff = ""

    static let singleHunkDiff = """
diff --git a/file.swift b/file.swift
index abc123..def456 100644
--- a/file.swift
+++ b/file.swift
@@ -1,5 +1,6 @@
 import Foundation

-let oldValue = 1
+let newValue = 2
+let anotherValue = 3

 func test() {}
"""

    static let multipleHunksDiff = """
diff --git a/file.swift b/file.swift
index abc123..def456 100644
--- a/file.swift
+++ b/file.swift
@@ -1,3 +1,4 @@
 import Foundation
+import SwiftUI

 struct Model {
@@ -10,5 +11,6 @@
 }

-// Old comment
+// New comment
+// Additional line

 let x = 1
"""

    static let multipleFilesDiff = """
diff --git a/first.swift b/first.swift
index abc123..def456 100644
--- a/first.swift
+++ b/first.swift
@@ -1,3 +1,3 @@
-let a = 1
+let a = 2
 let b = 3
 let c = 4
diff --git a/second.swift b/second.swift
index 111222..333444 100644
--- a/second.swift
+++ b/second.swift
@@ -5,3 +5,4 @@
 func test() {
     print("hello")
+    print("world")
 }
"""

    static let binaryFileDiff = """
diff --git a/image.png b/image.png
index abc123..def456 100644
Binary files a/image.png and b/image.png differ
"""

    static let renamedFileDiff = """
diff --git a/old.swift b/new.swift
similarity index 95%
rename from old.swift
rename to new.swift
index abc123..def456 100644
--- a/old.swift
+++ b/new.swift
@@ -1,3 +1,3 @@
-// Old file
+// New file
 let x = 1
 let y = 2
"""

    static let newFileDiff = """
diff --git a/new.swift b/new.swift
new file mode 100644
index 0000000..abc123
--- /dev/null
+++ b/new.swift
@@ -0,0 +1,3 @@
+import Foundation
+
+let newFile = true
"""

    static let deletedFileDiff = """
diff --git a/deleted.swift b/deleted.swift
deleted file mode 100644
index abc123..0000000
--- a/deleted.swift
+++ /dev/null
@@ -1,3 +0,0 @@
-import Foundation
-
-let deletedFile = true
"""

    // MARK: - Numstat Output Fixtures

    static let emptyNumstat = ""

    static let singleFileNumstat = "10\t5\tfile.swift"

    static let multipleFilesNumstat = "10\t5\tfile1.swift\n3\t1\tfile2.swift\n20\t15\tfile3.swift"

    static let binaryFileNumstat = "10\t5\tfile.swift\n-\t-\timage.png\n5\t2\tanother.swift"

    static let emptyChangesNumstat = "0\t0\tfile.swift"
}
