// Decompiled with JetBrains decompiler
// Type: StorageCraft.ImageManager.Client.Support.Client
// Assembly: ImageManager.Client, Version=6.5.4.36511, Culture=neutral, PublicKeyToken=null
// MVID: D11E9B9C-42C6-4361-9C69-95ACCF2E4E60
// Assembly location: C:\Program Files (x86)\StorageCraft\ImageManager\ImageManager.Client.exe

using StorageCraft.ImageManager.Interface;
using System;
using System.Collections;
using System.Runtime.Remoting;
using System.Runtime.Remoting.Channels;
using System.Runtime.Remoting.Channels.Tcp;
using System.Runtime.Serialization.Formatters;

namespace StorageCraft.ImageManager.Client.Support
{
  public class Client
  {
    private static readonly IChannel m_channel;

    static Client()
    {
        bool secure = true;
      IDictionary properties = (IDictionary) new Hashtable();
      properties[(object) "name"] = (object) Guid.NewGuid().ToString();
      properties[(object) "port"] = (object) 0;
      properties[(object) "connectionTimeout"] = (object) 15000;
      properties[(object)"secure"] = secure;
      BinaryClientFormatterSinkProvider formatterSinkProvider = new BinaryClientFormatterSinkProvider();
      Client.m_channel = (IChannel) new TcpChannel(properties, (IClientChannelSinkProvider) formatterSinkProvider, (IServerChannelSinkProvider) new BinaryServerFormatterSinkProvider()
      {
        TypeFilterLevel = TypeFilterLevel.Full
      });
      ChannelServices.RegisterChannel(Client.m_channel, secure);
    }

    public static IAgent Connect(string host, int port, string password)
    {
      return ((IAgentFactory) RemotingServices.Connect(typeof (IAgentFactory), string.Format("tcp://{0}:{1}/{2}", (object) host, (object) port, (object) "ImageManager4"))).Create(password);
    }
  }
}
