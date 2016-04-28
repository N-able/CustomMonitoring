using StorageCraft.ImageManager.Interface;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using StorageCraft.ImageManager.Client.Support;
using System.Management.Instrumentation;
using System.Management;
using System.Runtime.InteropServices;
using System.Reflection;
using System.Runtime.Remoting;
using System.IO;
using System.Xml;
using System.Xml.XPath;

namespace ImageManagerPoll
{
    class Program
    {
        public static string wmiNamespaceName = "NCentral";
        public static string wmiNamespaceString = "root\\cimv2\\"+wmiNamespaceName;
        public static string wmiClassString = "ImageManager";
        public static string eqLine = " ================================================= ";
        public static string dashline = " _________________________________________________ ";
        public static string tildaline =" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ";

        static int Main(string[] args)
        {
            try
            {
                Console.WriteLine("User profile path detected: "+Environment.GetEnvironmentVariable(Environment.SpecialFolder.UserProfile.ToString()));
                Console.WriteLine("Checking for existence of WMI namespace and class");
                try
                {
                    createOrUpdateWmi();
                }
                catch (Exception e)
                {
                    if (e.Message.StartsWith("Access denied"))
                    {
                        Console.WriteLine("Access to WMI denied, you must run this application as administrator");
                        return 1;
                    }
                    else
                    {
                        throw e;
                    }
                }

                string hashedPassword=null;
                if (args.Length > 0 && args[0] != null)
                {
                    foreach (string arg in args)
                    {
                        if (arg.ToLower().StartsWith("password="))
                        {
                            Console.WriteLine(arg);
                            string unhashedPassword = arg.Substring(9).Trim();
                            Console.WriteLine("Using ImageManager password supplied from command line ("+unhashedPassword.Length+" characters)");
                            PasswordHash hash = new PasswordHash();
                            hashedPassword = hash.ComputeAsBase64(unhashedPassword);
                        }
                    }
                }
                if (hashedPassword==null)
                {
                    Console.WriteLine("Looking for ImageManager hashed password from settings file");

                    DirectoryInfo testFolder = new DirectoryInfo("C:\\windows\\SysWOW64\\config\\systemprofile\\AppData\\local\\StorageCraft_Technology_C");

                    if (!testFolder.Exists)
                    {
                        testFolder = new DirectoryInfo("C:\\windows\\System32\\config\\systemprofile\\AppData\\local\\StorageCraft_Technology_C");
                        if (!testFolder.Exists)
                        {
                            testFolder = new DirectoryInfo("C:\\Documents and Settings\\Default User\\Local Settings\\Application Data\\StorageCraft_Technology_C");
                            if (!testFolder.Exists)
                            {
                                Console.WriteLine("Unable to locate StorageCraft_Technology_C under the local system profile path. Check that the ImageManager service is running under the Local System account and that a password has been set.");
                                return 1;
                            }
                        }
                    }
                 
                    

                    Console.WriteLine("Found StorageCraft data folder at " + testFolder.FullName);
                    DirectoryInfo[] directories = testFolder.GetDirectories();
                    if (directories.Length == 0)
                    {
                        Console.WriteLine("Error: No subdirectory found under " + testFolder.Name);
                        return 1;
                    }
                    Console.WriteLine("Navigating down first subdirectory of " + testFolder.Name);
                    DirectoryInfo imageManagerDataFolder = new DirectoryInfo(directories[0].FullName);
                    directories = imageManagerDataFolder.GetDirectories();
                    if (directories.Length == 0)
                    {
                        Console.WriteLine("Error: No subdirectory found under " + testFolder.Name);
                        return 1;
                    }
                    Console.WriteLine("Navigating down newest subdirectory of " + imageManagerDataFolder.Name);
                    IEnumerator<DirectoryInfo> orderedDirectories = directories.OrderByDescending(d => d.Name).GetEnumerator();
                    orderedDirectories.MoveNext();
                    string userConfigFile = orderedDirectories.Current.FullName + "\\user.config";
                    Console.WriteLine("Attempting to read hashed password from '" + userConfigFile + "'");
                    XPathDocument reader = new XPathDocument(userConfigFile);
                    XPathNavigator navigator = reader.CreateNavigator();
                    XPathNodeIterator iterator = navigator.Select("/configuration/userSettings/StorageCraft.ImageManager.Properties.Settings/setting[@name='password']/value");
                    iterator.MoveNext();
                    hashedPassword = iterator.Current.Value;
                    Console.WriteLine("Password obtained from file");
                }

                Console.WriteLine("Connecting to ImageManager service");

                // using the IAgent interface instead of IAgent3 for compatibility with older versions.
                // None of the data we query for monitoring relies on the IAgent3 interface.
                IAgent agent = (IAgent)Client.Connect("localhost", 56765, hashedPassword);
                if (agent == null)
                {
                    Console.WriteLine("Incorrect password provided for local ImageManager service");
                    return 1;
                }
                agent.Ping();
                Console.WriteLine("Retrieving list of Managed Folders");
                List<ManagedFolder> allFolders = agent.ManagedFolders;
                string allFoldersText = "";
                // we put all managed folders in each folder instance, because the StorageCraft ImageManager Job List service just grabs the first one
                foreach (ManagedFolder folder in allFolders)
                {
                    allFoldersText = allFoldersText + eqLine + folder.Path;
                }
                foreach (ManagedFolder folder in allFolders)
                {
                    Console.WriteLine("--------------------------------------------");
                    Console.WriteLine("Found folder: '" + folder.Path);
                    Console.WriteLine("  State: " + folder.State);
                    int stateValue;
                    switch (folder.State)
                    {
                        case FolderState.Active: stateValue = 0; break;
                        case FolderState.Syncing: stateValue = 1; break;
                        case FolderState.Offline: stateValue = 2; break;
                        case FolderState.Failure: stateValue = 3; break;
                        default: throw new Exception("Unhandled job state value " + folder.State.ToString());
                    }
                    Console.WriteLine("  State Value: " + stateValue);

                    Console.WriteLine("  Machine Name: " + folder.ImagedComputer);
                    Console.WriteLine("  File Count: " + folder.ImageFileCount);
                    //Console.WriteLine("ParentID:  " + folder.ParentFolderId);
                    //Console.WriteLine("FolderID:  " + folder.Id);
                    
                    IFolderServiceLocator locator = agent.Services;
                    Console.WriteLine("Querying verification data");

                    IVerificationService verificationService = locator.Find<IVerificationService>(folder.Id);

                    VerificationPolicy parentVPolicy;
                    VerificationPolicy folderVPolicy;
                    VerificationPolicy vEffective = null;


                    //Set Parent and Child Policies based on whether or not the folder is a Parent folder or not.
                    if (folder.ParentFolderId != Guid.Empty)
                    {
                        parentVPolicy = locator.Find<IVerificationService>(folder.ParentFolderId).Policy;
                        folderVPolicy = locator.Find<IVerificationService>(folder.Id).Policy;
                    }
                    else
                    {
                        parentVPolicy = null;
                        folderVPolicy = locator.Find<IVerificationService>(folder.Id).Policy;
                    }

                    //Determine the effective Verification Policy on the folder.
                    vEffective = VerificationPolicy.ResolveEffectivePolicy(parentVPolicy, folderVPolicy);

                    String lastSuccessfulVerification = (DateTime.MinValue.Equals(verificationService.LastSuccessTime) ? "Never" : verificationService.LastSuccessTime.ToString());

                    Console.WriteLine("Verification Policy:");
                    Console.WriteLine("  VerifyNewImages:" + vEffective.VerifyNewImages);
                    Console.WriteLine("  ReverifyExistingImages:" + vEffective.ReverifyExistingImages);
                    Console.WriteLine("  ReverifyInterval: " + vEffective.ReverifyInterval);
                    Console.WriteLine("Last successful verification: " + lastSuccessfulVerification);
                    Console.WriteLine("Number of failures detected: " + verificationService.Failures.Count);
                    List<VerificationFailure> sortedVerificationFailures = verificationService.Failures.OrderByDescending(o => o.FailureTime).ToList();
                    string verificationFailureDetails = (verificationService.Failures.Count > 0 ? "" : "N/A");
                    foreach (VerificationFailure failure in sortedVerificationFailures)
                    {
                        Console.WriteLine("Verification failure detected - " + failure.FailureTime.ToString() + ": " + failure.Reason);
                        verificationFailureDetails += dashline + " " + failure.FailureTime.ToString() + ": " + failure.Reason + " ";
                    }


                    Console.WriteLine("Querying consolidation data");
                    IConsolidationService consolidationService = locator.Find<IConsolidationService>(folder.Id);
                    Console.WriteLine("Consolidation Policy:");
                    Console.WriteLine("  ConsolidationEnabled:" + consolidationService.Policy.IsEnabled);
                    Console.WriteLine("  MonthlyConsolidationDay:" + consolidationService.Policy.MonthlyConsolidationDay);
                    Console.WriteLine("  MonthlyConsolidationDayOfWeek:" + consolidationService.Policy.MonthlyConsolidationDayOfWeek);
                    Console.WriteLine("  MonthlyConsolidationWeek:" + consolidationService.Policy.MonthlyConsolidationWeek);
                    Console.WriteLine("  WeeklyConsolidationDay:" + consolidationService.Policy.WeeklyConsolidationDay);

                    String lastSuccessfulConsolidation = (DateTime.MinValue.Equals(consolidationService.LastSuccessTime) ? "Never" : consolidationService.LastSuccessTime.ToString());
                    Console.WriteLine("Last successful consolidation: " + lastSuccessfulConsolidation + ", number of failures detected: " + consolidationService.Failures.Count);
                    Console.WriteLine("last consolidation success message: " + consolidationService.LastSuccessMessage);
                    List<ConsolidationFailure> sortedConsolidationFailures = consolidationService.Failures.OrderByDescending(o => o.FailureTime).ToList();
                    string consolidationFailureDetails = (consolidationService.Failures.Count > 0 ? eqLine : "N/A");
                    foreach (ConsolidationFailure failure in consolidationService.Failures)
                    {
                        Console.WriteLine("Consolidation failure detected - " + failure.FailureTime.ToString() + ": " + failure.Reason);
                        consolidationFailureDetails += " " + failure.FailureTime.ToString() + ": " + failure.Reason + " " + dashline;
                    }


                    Console.WriteLine("Querying replication data");
                    // using the IReplicationService interface instead of IReplicationService2 for compatibility with older versions.
                    // None of the data we query for monitoring relies on the IReplicationService2 interface.
                    IReplicationService replicationService = locator.Find<IReplicationService>(folder.Id);
                    int failedReplications = 0;
                    int queuedFiles = 0;
                    string replicationTargetsText = (replicationService.Targets.Count > 0 ? "" : "N/A");
                    foreach (ReplicationTarget target in replicationService.Targets)
                    {
                        Console.WriteLine("Replication Target Found: " + target.FullPath);
                        Console.WriteLine("  Type: " + target.Destination.Type.ToString() + ", Successful: " + target.IsSuccessful + ", Status: " + target.Status.Text + ", Queued Files: " + target.Status.QueuedFiles);

                        if (!target.IsSuccessful)
                        {
                            failedReplications++;
                        }
                        queuedFiles += (int)target.Status.QueuedFiles;
                        replicationTargetsText += eqLine + "Path: " + target.FullPath + eqLine +
                                                          "Type: " + target.Destination.Type.ToString() + dashline +
                                                          "Queued Files Count: " + target.Status.QueuedFiles +dashline +
                                                          "Status: " + target.Status.Text + dashline +
                                                          "Successful: " + target.IsSuccessful + dashline;

                    }
                    Console.WriteLine("Failed replication targets: " + failedReplications);


                    Console.WriteLine("Querying retention data");

                    IRetentionService retentionService = locator.Find<IRetentionService>(folder.Id);

                    RetentionPolicy parentRPolicy;
                    RetentionPolicy folderRPolicy;
                    RetentionPolicy retentionPolicy = null;
                    bool retentionPolicyInheritedFromGlobal = retentionService.Policy == null;


                    //Set Parent and Child Policies based on whether or not the folder is a Parent folder or not.
                    if (folder.ParentFolderId != Guid.Empty)
                    {
                        parentRPolicy = locator.Find<IRetentionService>(folder.ParentFolderId).Policy;
                        folderRPolicy = locator.Find<IRetentionService>(folder.Id).Policy;
                    }
                    else
                    {
                        parentRPolicy = null;
                        folderRPolicy = locator.Find<IRetentionService>(folder.Id).Policy;
                    }

                    //Determine the effective Retention Policy on the folder.
                    retentionPolicy = RetentionPolicy.ResolveEffectivePolicy(agent.AgentSettings.AgentRetentionPolicy, parentRPolicy, folderRPolicy);


                    //Removed on 4/13/2016 and implemented ResolveEffectivePolicy built into ImageManager 7.0.2.      
                    //if (retentionPolicyInheritedFromGlobal)
                    //{
                    //    try
                    //   {
                    //        retentionPolicy = agent.AgentSettings.AgentRetentionPolicy;
                    //    }
                    //    catch (TypeLoadException e)
                    //    {
                    //type won't exist in the dll prior to 6.0
                    //    }
                    //}
                    //else
                    //{
                    //    retentionPolicy = retentionService.Policy;
                    //}

                    Console.WriteLine("Number of retention issues: " + retentionService.Issues.Count);
                    Console.WriteLine("Retention Policy:");
                   
                    Console.WriteLine("  InheritedFromGlobal:" + retentionPolicyInheritedFromGlobal);
                    Console.WriteLine("  RetentionEnabled:" + retentionPolicy.IsEnabled);
                    Console.WriteLine("  DaysToRetainIntraDailyImages:" + retentionPolicy.DaysToRetainIntraDailyImages);
                    Console.WriteLine("  DaysToRetainConsolidatedDailyImages:" + retentionPolicy.DaysToRetainConsolidatedDailyImages);
                    Console.WriteLine("  DaysToRetainConsolidatedWeeklyImages:" + retentionPolicy.DaysToRetainConsolidatedWeeklyImages);
                    try
                    {
                        retentionPolicy.MonthsToRetainConsolidatedMonthlyImages = -1;
                        Console.WriteLine("  MonthsToRetainConsolidatedMonthlyImages:" + retentionPolicy.MonthsToRetainConsolidatedMonthlyImages);
                        Console.WriteLine("  MonthlyRetentionIsSupported:" + retentionPolicy.MonthlyRetentionIsSupported);
                    }
                    catch (TypeLoadException e)
                    {
                        // type won't exist in the dll prior to 6.0
                    }
                    Console.WriteLine("  MoveConsolidatedImages:" + retentionPolicy.MoveConsolidatedImages);
                    string retentionIssuesText = (retentionService.Issues.Count > 0 ? "" : "N/A");
                    foreach (RetentionIssue issue in retentionService.Issues)
                    {
                        Console.WriteLine(issue.IssueTime + " Reason: " + issue.Reason);
                        retentionIssuesText += dashline + " " + issue.IssueTime.ToString() + ": " + issue.Reason + " ";
                    }


                    Console.WriteLine("Querying Headstart Restore data");
                    // using the IHeadStartService interface instead of IHeadStartService2 for compatibility with older versions.
                    // None of the data we query for monitoring relies on the IHeadStartService2 interface.
                    IHeadStartService headStartService = locator.Find<IHeadStartService>(folder.Id);
                    int failedHeadstartJobs = 0;
                    string headstartJobsText = (headStartService.FindAllJobs().Count > 0 ? "" : "N/A");
                    foreach (HeadStartJob job in headStartService.FindAllJobs())
                    {
                        Console.WriteLine("Headstart Restore Job Found: " + job.Name + ", Destination: '" + job.Destination.Path + "', State: " + job.State.ToString());
                        if (job.State.Equals(HeadStartState.Failure))
                        {
                            failedHeadstartJobs++;
                        }
                        headstartJobsText += eqLine + "Job Name: " + job.Name +eqLine +
                                                          "Destination Path: " + job.Destination.Path + dashline +
                                                          "State: " + job.State.ToString() + dashline;
                        foreach (HeadStartTarget target in job.Targets)
                        {
                            headstartJobsText += "Target " + target.Id + tildaline+
                                                 "Status: " + target.Status.Text + tildaline +
                                                 "LastAppliedSnapshotTime: " + target.Status.LastAppliedSnapshotTime + tildaline +
                                                 "UnappliedSnapshotDays: " + target.UnappliedSnapshotDays.Count + dashline;

                        }

                    }
                    Console.WriteLine("Failed headstart restore jobs: " + failedHeadstartJobs);

                    PutOptions options = new PutOptions();
                    options.Type = PutType.UpdateOrCreate;
                    ManagementClass objHostSettingClass = new ManagementClass(wmiNamespaceString, wmiClassString, null);
                    ManagementObject wmiObject = objHostSettingClass.CreateInstance();

                    wmiObject.SetPropertyValue("ManagedFolder", folder.Path);
                    wmiObject.SetPropertyValue("MachineName", folder.ImagedComputer);
                    wmiObject.SetPropertyValue("OverallState", folder.State);
                    wmiObject.SetPropertyValue("OverallStateValue", stateValue);
                    wmiObject.SetPropertyValue("FileCount", folder.ImageFileCount);

                    wmiObject.SetPropertyValue("NumberOfFilesFailingVerification", verificationService.Failures.Count);
                    wmiObject.SetPropertyValue("VerificationFailureDetails", verificationFailureDetails);
                    wmiObject.SetPropertyValue("LastSuccessfulVerification", lastSuccessfulVerification);
                    wmiObject.SetPropertyValue("VerifyNewImages", vEffective.VerifyNewImages);
                    wmiObject.SetPropertyValue("ReverifyExistingImages", vEffective.ReverifyExistingImages);
                    wmiObject.SetPropertyValue("ReverifyInterval", vEffective.ReverifyInterval);

                    wmiObject.SetPropertyValue("ConsolidationEnabled", consolidationService.Policy.IsEnabled);
                    wmiObject.SetPropertyValue("LastSuccessfulConsolidation", lastSuccessfulConsolidation);
                    wmiObject.SetPropertyValue("NumberOfFilesFailingConsolidation", consolidationService.Failures.Count);
                    wmiObject.SetPropertyValue("ConsolidationFailureDetails", consolidationFailureDetails);

                    wmiObject.SetPropertyValue("ReplicationTargetDetails", replicationTargetsText);
                    wmiObject.SetPropertyValue("FailedReplications", failedReplications);
                    wmiObject.SetPropertyValue("NumberOfFilesQueuedForReplication", queuedFiles);



                    wmiObject.SetPropertyValue("RetentionIssues", retentionService.Issues.Count);
                    wmiObject.SetPropertyValue("RetentionIssueDetails", retentionIssuesText);
                    wmiObject.SetPropertyValue("RetentionEnabled", retentionPolicy.IsEnabled);
                    wmiObject.SetPropertyValue("RetentionPolicyInheritedFromGlobal", retentionPolicyInheritedFromGlobal);
                    wmiObject.SetPropertyValue("DaysToRetainIntraDailyImages", retentionPolicy.DaysToRetainIntraDailyImages);
                    wmiObject.SetPropertyValue("DaysToRetainConsolidatedDailyImages", retentionPolicy.DaysToRetainConsolidatedDailyImages);
                    wmiObject.SetPropertyValue("DaysToRetainConsolidatedWeeklyImages", retentionPolicy.DaysToRetainConsolidatedWeeklyImages);
                    wmiObject.SetPropertyValue("MonthsToRetainConsolidatedMonthlyImages", retentionPolicy.MonthsToRetainConsolidatedMonthlyImages);
                    wmiObject.SetPropertyValue("MonthlyRetentionIsSupported", retentionPolicy.MonthlyRetentionIsSupported);
                    wmiObject.SetPropertyValue("MoveConsolidatedImages", retentionPolicy.MoveConsolidatedImages);

                    wmiObject.SetPropertyValue("FailedHeadstartJobs", failedHeadstartJobs);
                    wmiObject.SetPropertyValue("HeadstartJobDetails", headstartJobsText);

                    wmiObject.SetPropertyValue("LastScriptRunTime", DateTime.Now.ToString());

                    SelectQuery selectQuery = new SelectQuery("select * from win32_utctime");
                    ManagementObjectSearcher searcher = new ManagementObjectSearcher(selectQuery);
                    ManagementObjectCollection utcTimeFromWmi = searcher.Get();
                    ManagementObjectCollection.ManagementObjectEnumerator enumerator = utcTimeFromWmi.GetEnumerator();
                    enumerator.MoveNext();
                    ManagementBaseObject mbo = enumerator.Current;

                    UInt32 year = (UInt32)mbo.GetPropertyValue("Year");
                    UInt32 month = (UInt32)mbo.GetPropertyValue("Month");
                    UInt32 day = (UInt32)mbo.GetPropertyValue("Day");
                    UInt32 hour = (UInt32)mbo.GetPropertyValue("Hour");
                    UInt32 min = (UInt32)mbo.GetPropertyValue("Minute");
                    UInt32 second = (UInt32)mbo.GetPropertyValue("Second");

                    long timestamp = ((((((year - 1970) * 31556926) + ((month - 1) * 2678400)) + ((day - 1) * 86400)) + (hour * 3600)) + (min * 60)) + (second);
                    wmiObject.SetPropertyValue("Timestamp", timestamp);

                    wmiObject.SetPropertyValue("ListOfAllManagedFolders", allFoldersText);

                    wmiObject.Put(options);
                }
                Console.WriteLine("--------------------------------------------");
                Console.WriteLine("Poll complete");
                return 0;
            }
            catch (Exception e)
            {
                Console.WriteLine("Fatal error: "+e.Message);
                return 1;
            }
        }

        public static IAgent Connect(string host, int port, string password)
        {
            return ((IAgentFactory)RemotingServices.Connect(typeof(IAgentFactory), string.Format("tcp://{0}:{1}/{2}", (object)host, (object)port, (object)"ImageManager4"))).Create(password);
        }

        static void createOrUpdateWmi()
        {
            Console.WriteLine("Checking for namespace " + wmiNamespaceString+", and creating if missing");
            PutOptions options = new PutOptions();
            options.Type = PutType.UpdateOrCreate;
            ManagementClass objHostSettingClass = new ManagementClass("root\\cimv2", "__Namespace", null);
            ManagementObject wmiObject = objHostSettingClass.CreateInstance();
            wmiObject.SetPropertyValue("Name", wmiNamespaceName);
            wmiObject.Put(options);

            System.Management.ManagementClass wmiClass;
            try
            {
                wmiClass = new System.Management.ManagementClass(wmiNamespaceString, wmiClassString, null);
                wmiClass.CreateInstance();
                Console.WriteLine(wmiClassString + " class exists");
            }
            catch (ManagementException me)
            {
                Console.WriteLine(wmiClassString + " class does not exist, creating");
                wmiClass = new System.Management.ManagementClass(wmiNamespaceString, null, null);
                wmiClass["__CLASS"] = wmiClassString;
                wmiClass.Qualifiers.Add("Static", true);
                wmiClass.Put();

            }

            if (!testValueExists(wmiClass, "ManagedFolder"))
            {
                wmiClass.Properties.Add("ManagedFolder", System.Management.CimType.String, false);
                wmiClass.Properties["ManagedFolder"].Qualifiers.Add("Key", true);
            }
            if (!testValueExists(wmiClass, "MachineName")) { wmiClass.Properties.Add("MachineName", System.Management.CimType.String, false); }
            if (!testValueExists(wmiClass, "OverallState")) { wmiClass.Properties.Add("OverallState", System.Management.CimType.String, false); }
            if (!testValueExists(wmiClass, "OverallStateValue")) { wmiClass.Properties.Add("OverallStateValue", System.Management.CimType.UInt32, false); }
            if (!testValueExists(wmiClass, "FileCount")) { wmiClass.Properties.Add("FileCount", System.Management.CimType.UInt64, false); }

            if (!testValueExists(wmiClass, "NumberOfFilesFailingVerification")) { wmiClass.Properties.Add("NumberOfFilesFailingVerification", System.Management.CimType.UInt32, false); }
            if (!testValueExists(wmiClass, "VerificationFailureDetails")) { wmiClass.Properties.Add("VerificationFailureDetails", System.Management.CimType.String, false); }
            if (!testValueExists(wmiClass, "LastSuccessfulVerification")) { wmiClass.Properties.Add("LastSuccessfulVerification", System.Management.CimType.String, false); }
            if (!testValueExists(wmiClass, "VerifyNewImages")) { wmiClass.Properties.Add("VerifyNewImages", System.Management.CimType.Boolean, false); }
            if (!testValueExists(wmiClass, "ReverifyExistingImages")) { wmiClass.Properties.Add("ReverifyExistingImages", System.Management.CimType.Boolean, false); }
            if (!testValueExists(wmiClass, "ReverifyInterval")) { wmiClass.Properties.Add("ReverifyInterval", System.Management.CimType.SInt32, false); }

            if (!testValueExists(wmiClass, "ConsolidationEnabled")) { wmiClass.Properties.Add("ConsolidationEnabled", System.Management.CimType.Boolean, false); }
            if (!testValueExists(wmiClass, "LastSuccessfulConsolidation")) { wmiClass.Properties.Add("LastSuccessfulConsolidation", System.Management.CimType.String, false); }
            if (!testValueExists(wmiClass, "NumberOfFilesFailingConsolidation")) { wmiClass.Properties.Add("NumberOfFilesFailingConsolidation", System.Management.CimType.UInt32, false); }
            if (!testValueExists(wmiClass, "ConsolidationFailureDetails")) { wmiClass.Properties.Add("ConsolidationFailureDetails", System.Management.CimType.String, false); }

            if (!testValueExists(wmiClass, "FailedReplications")) { wmiClass.Properties.Add("FailedReplications", System.Management.CimType.UInt32, false); }
            if (!testValueExists(wmiClass, "NumberOfFilesQueuedForReplication")) { wmiClass.Properties.Add("NumberOfFilesQueuedForReplication", System.Management.CimType.UInt32, false); }
            if (!testValueExists(wmiClass, "ReplicationTargetDetails")) { wmiClass.Properties.Add("ReplicationTargetDetails", System.Management.CimType.String, false); }


            if (!testValueExists(wmiClass, "RetentionIssues")) { wmiClass.Properties.Add("RetentionIssues", System.Management.CimType.UInt32, false); }
            if (!testValueExists(wmiClass, "RetentionIssueDetails")) { wmiClass.Properties.Add("RetentionIssueDetails", System.Management.CimType.String, false); }
            if (!testValueExists(wmiClass, "RetentionEnabled")) { wmiClass.Properties.Add("RetentionEnabled", System.Management.CimType.Boolean, false); }
            if (!testValueExists(wmiClass, "RetentionPolicyInheritedFromGlobal")) { wmiClass.Properties.Add("RetentionPolicyInheritedFromGlobal", System.Management.CimType.Boolean, false); }
            if (!testValueExists(wmiClass, "DaysToRetainIntraDailyImages")) { wmiClass.Properties.Add("DaysToRetainIntraDailyImages", System.Management.CimType.SInt32, false); }
            if (!testValueExists(wmiClass, "DaysToRetainConsolidatedDailyImages")) { wmiClass.Properties.Add("DaysToRetainConsolidatedDailyImages", System.Management.CimType.SInt32, false); }
            if (!testValueExists(wmiClass, "DaysToRetainConsolidatedWeeklyImages")) { wmiClass.Properties.Add("DaysToRetainConsolidatedWeeklyImages", System.Management.CimType.SInt32, false); }
            if (!testValueExists(wmiClass, "MonthsToRetainConsolidatedMonthlyImages")) { wmiClass.Properties.Add("MonthsToRetainConsolidatedMonthlyImages", System.Management.CimType.SInt32, false); }
            if (!testValueExists(wmiClass, "DaysToRetainIntraDailyImages")) { wmiClass.Properties.Add("DaysToRetainIntraDailyImages", System.Management.CimType.SInt32, false); }
            if (!testValueExists(wmiClass, "MonthlyRetentionIsSupported")) { wmiClass.Properties.Add("MonthlyRetentionIsSupported", System.Management.CimType.Boolean, false); }
            if (!testValueExists(wmiClass, "MoveConsolidatedImages")) { wmiClass.Properties.Add("MoveConsolidatedImages", System.Management.CimType.Boolean, false); }


            if (!testValueExists(wmiClass, "FailedHeadstartJobs")) { wmiClass.Properties.Add("FailedHeadstartJobs", System.Management.CimType.UInt32, false); }
            if (!testValueExists(wmiClass, "HeadstartJobDetails")) { wmiClass.Properties.Add("HeadstartJobDetails", System.Management.CimType.String, false); }


            if (!testValueExists(wmiClass, "LastScriptRunTime")) { wmiClass.Properties.Add("LastScriptRunTime", System.Management.CimType.String, false); }
            if (!testValueExists(wmiClass, "Timestamp")) { wmiClass.Properties.Add("Timestamp", System.Management.CimType.UInt64, false); }
            if (!testValueExists(wmiClass, "ListOfAllManagedFolders")) { wmiClass.Properties.Add("ListOfAllManagedFolders", System.Management.CimType.String, false); }



            try
            {
                wmiClass.Put();
            }
            catch (ManagementException me)
            {
                if (me.ErrorCode.Equals(ManagementStatus.ClassHasInstances))
                {
                    Console.WriteLine("Deleting existing instances of " + wmiClassString);
                    ManagementObjectSearcher searcher = new ManagementObjectSearcher(wmiNamespaceString, "SELECT * FROM " + wmiClassString);
                    foreach (ManagementObject queryObj in searcher.Get())
                    {
                        queryObj.Delete();
                    }
                    wmiClass.Put();
                }
                else
                {
                    throw me;
                }
            }
        }

        static bool testValueExists(System.Management.ManagementClass instance, String value)
        {
            try
            {
                instance.GetPropertyValue(value);
            }
            catch (System.Management.ManagementException me)
            {
                if (me.ErrorCode.Equals(System.Management.ManagementStatus.NotFound))
                {
                    return false;
                }
                throw me;
            }
            return true;

        }
    }
}
