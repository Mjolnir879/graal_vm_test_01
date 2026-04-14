[INFO] Scanning for projects...
[INFO] 
[INFO] --------------------------< com.example:demo >--------------------------
[INFO] Building  0.0.1-SNAPSHOT
[INFO]   from pom.xml
[INFO] --------------------------------[ jar ]---------------------------------
[INFO] 
[INFO] --- spring-boot:4.0.5:process-aot (default-cli) @ demo ---
[INFO] ------------------------------------------------------------------------
[INFO] BUILD FAILURE
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  1.406 s
[INFO] Finished at: 2026-04-14T20:52:41Z
[INFO] ------------------------------------------------------------------------
[ERROR] Failed to execute goal org.springframework.boot:spring-boot-maven-plugin:4.0.5:process-aot (default-cli) on project demo: Unable to find a suitable main class, please add a 'mainClass' property -> [Help 1]
[ERROR] 
[ERROR] To see the full stack trace of the errors, re-run Maven with the -e switch.
[ERROR] Re-run Maven using the -X switch to enable full debug logging.
[ERROR] 
[ERROR] For more information about the errors and possible solutions, please read the following articles:
[ERROR] [Help 1] http://cwiki.apache.org/confluence/display/MAVEN/MojoExecutionException
Dockerfile:35
-------------------
34 |     COPY src ./src
35 | >>> RUN mvn -Pnative -DskipTests -B \
36 | >>>         spring-boot:process-aot \
37 | >>>         native:compile
38 |
-------------------
ERROR: failed to build: failed to solve: process "/bin/sh -c mvn -Pnative -DskipTests -B         spring-boot:process-aot         native:compile" did not complete successfully: exit code: 1