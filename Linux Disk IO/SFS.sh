# The activation code found in N-central
ACTIVATIONCODE=23353b4-3cef

# Count the number of instances found
#bytes read per ssec
SCANDETAIL1NAME="EDF15599_1"
SCANDETAIL1VALUE=`sar -b|awk '{print$5}'|tail -1`

# The string that was found
#btyes written per second
SCANDETAIL2NAME="EDF15599_2"
SCANDETAIL2VALUE=`sar -b|awk '{print$6}'|tail -1`

# Debugging statements
echo Activation Code: $ACTIVATIONCODE
echo "$SCANDETAIL1NAME":\"$SCANDETAIL1VALUE\"
echo "$SCANDETAIL2NAME":\"$SCANDETAIL2VALUE\"

# the class path for java
CPATH=axis/WEB-INF/lib/commons-collections-2.1.1.jar:axis/WEB-INF/lib/jline.jar:axis/WEB-INF/lib/axis.jar:axis/WEB-INF/lib/commons-digester.jar:axis/WEB-INF/lib/log4j-1.2.8.jar:axis/WEB-INF/lib/bcprov-jdk14-126.jar:axis/WEB-INF/lib/commons-discovery.jar:axis/WEB-INF/lib/jaxrpc.jar:axis/WEB-INF/lib/saaj.jar:axis/WEB-INF/lib/commons-beanutils.jar:axis/WEB-INF/lib/commons-logging.jar:axis/WEB-INF/lib/wsdl4j.jar:axis/WEB-INF/lib/dmsapi.jar:jar/EDFGenApp.jar:resources
#CPATH=axis/WEB-INF/lib/commons-collections-2.1.1.jar:axis/WEB-INF/lib/jline.jar:axis/WEB-INF/lib/axis.jar:axis/WEB-INF/lib/commons-digester.jar:axis/WEB-INF/lib/log4j-1.2.8.jar:axis/WEB-INF/lib/bcprov-jdk14-126.jar:axis/WEB-INF/lib/commons-discovery.jar:axis/WEB-INF/lib/jaxrpc.jar:axis/WEB-INF/lib/saaj.jar:axis/WEB-INF/lib/commons-beanutils.jar:axis/WEB-INF/lib/commons-logging.jar:axis/WEB-INF/lib/wsdl4j.jar:axis/WEB-INF/lib/dmsapi.jar:bin

# go!  any additional scandetails can be added to the end of the line in a simillar manner
java -cp $CPATH com.nable.server.edf.GenericApp.EDFGenericApp $ACTIVATIONCODE "$SCANDETAIL1NAME:$SCANDETAIL1VALUE" "$SCANDETAIL2NAME:$SCANDETAIL2VALUE"

~