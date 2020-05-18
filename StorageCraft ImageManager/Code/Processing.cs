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

namespace ImageManagerProcessing
{
    class Program
    {
        public static string wmiNamespaceName = "NCentral";
        public static string wmiNamespaceString = "root\\cimv2\\" + wmiNamespaceName;
        public static string wmiClassString = "ImageManager";
        public static string eqLine = " ================================================= ";
        public static string dashline = " _________________________________________________ ";
        public static string tildaline = " ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ";

        static int Main(string[] args)
        {
            try
            {
                Console.WriteLine("User profile path detected: " + Environment.GetEnvironmentVariable(Environment.SpecialFolder.UserProfile.ToString()));
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

                string hashedPassword = null;
                if (args.Length > 0 && args[0] != null)
                {
                    foreach (string arg in args)
                    {
                        if (arg.ToLower().StartsWith("password="))
                        {
                            Console.WriteLine(arg);
                            string unhashedPassword = arg.Substring(9).Trim();
                            Console.WriteLine("Using ImageManager password supplied from command line (" + unhashedPassword.Length + " characters)");
                            PasswordHash hash = new PasswordHash();
                            hashedPassword = hash.ComputeAsBase64(unhashedPassword);
                        }
                    }
                }
                if (hashedPassword == null)
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
                IAgent5 agent = (IAgent5)Client.Connect("localhost", 56765, hashedPassword);
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
                    if (folder.FolderType != FolderType.StoreParent)
                    {
                        allFoldersText = allFoldersText + eqLine + folder.Path;
                    }
                }
                foreach (ManagedFolder folder in allFolders)
                {
                    if (folder.FolderType != FolderType.StoreParent)
                    {
                        StartProcessing(folder.Id);
                        Console.WriteLine("Starting processing on " + folder.Path);
                    }
                }
            }
            catch (Exception e)
            {
                Console.WriteLine("Fatal error: " + e.Message);
                return 1;
            }

        }
        public static IAgent Connect(string host, int port, string password)
        {
            return ((IAgentFactory)RemotingServices.Connect(typeof(IAgentFactory), string.Format("tcp://{0}:{1}/{2}", (object)host, (object)port, (object)"ImageManager4"))).Create(password);
        }
    }


                        