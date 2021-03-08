using System;
using System.Collections.Generic;
using System.IO;
using System.Xml;
using System.Xml.Serialization;

namespace PsFCIV.Support {
    /// <summary>
    /// Represents a root node for FCIV database.
    /// </summary>
    [XmlType(AnonymousType = true)]
    [XmlRoot("FCIV", Namespace = "", IsNullable = false)]
    public class FcivRootNode {
        /// <summary>
        /// Gets or sets a collection of FCIV file entries.
        /// </summary>
        [XmlElement("FILE_ENTRY")]
        public HashSet<FcivFileEntry> Entries { get; set; } = new HashSet<FcivFileEntry>();

        public void SaveToFile(String dbFilePath) {
            using (var fs = new FileStream(dbFilePath, FileMode.Create)) {
                var xml = new XmlSerializer(typeof(FcivRootNode));
                var xns = new XmlSerializerNamespaces();
                XmlWriterSettings settings = new XmlWriterSettings {
                    Indent = false,
                    NewLineHandling = NewLineHandling.None
                };
                xns.Add("", "");
                using (XmlWriter writer = XmlWriter.Create(fs, settings)) {
                    xml.Serialize(writer, this, xns);
                }
            }
        }

        public static FcivRootNode ReadFromFile(String dbFilePath) {
            using (var fs = new FileStream(dbFilePath, FileMode.Open)) {
                var xml = new XmlSerializer(typeof(FcivRootNode));
                return (FcivRootNode)xml.Deserialize(fs);
            }
        }
    }
}