export JAVA_VERSION="1.8"

export JAVA_HOME=`/usr/libexec/java_home -v $JAVA_VERSION`
export JVM_ARGS="-Xms1024m -Xmx1024m"

switchJava() {
   if [[ ! -x /usr/libexec/java_home ]]; then
      echo "/usr/libexec/java_home not found!" 1>&2
      return
   fi
   if [[ $JAVA_VERSION == "1.7" ]]; then
      export JAVA_VERSION="1.8"
      export JAVA_HOME=`/usr/libexec/java_home -v $JAVA_VERSION`
   elif [[ $JAVA_VERSION == "1.8" ]]; then
      export JAVA_VERSION="9"
      export JAVA_HOME=`/usr/libexec/java_home -v $JAVA_VERSION`
   else
      export JAVA_VERSION="1.7"
      export JAVA_HOME=`/usr/libexec/java_home -v $JAVA_VERSION`
   fi
   echo "Switching to java $JAVA_VERSION"
}
export STUDIO_JDK=$JAVA_HOME



