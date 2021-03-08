using System;
using System.Globalization;
using System.IO;
using System.Xml.Serialization;

namespace PsFCIV.Support {
    [XmlType(AnonymousType = true)]
    public class FcivFileEntry {
        public FcivFileEntry() { }
        public FcivFileEntry(String path) {
            Name = path;
            if (File.Exists(path)) {
                var fi = new FileInfo(path);
                Size = fi.Length;
                TimeStamp = fi.LastWriteTimeUtc.ToString(CultureInfo.InvariantCulture);
            }
        }

        // seems original FCIV tool is strict on lower-case of 'name' property
        /// <summary>
        /// Gets or sets the file name and path relative to working directory.
        /// </summary>
        [XmlElement("name")]
        public String Name { get; set; }
        /// <summary>
        /// Gets or sets the file size in bytes.
        /// </summary>
        public Int64 Size { get; set; }
        /// <summary>
        /// Gets or sets the file's <see cref="FileInfo.LastWriteTime">LastWriteTime</see> attribute. Timestamp is stored in UTC time zone.
        /// </summary>
        public String TimeStamp { get; set; }
        /// <summary>
        /// Gets or sets a base64-encoded MD5 hash of the file.
        /// </summary>
        public String MD5 { get; set; }
        /// <summary>
        /// Gets or sets a base64-encoded SHA1 hash of the file
        /// </summary>
        public String SHA1 { get; set; }
        /// <summary>
        /// Gets or sets a base64-encoded SHA256 hash of the file
        /// </summary>
        public String SHA256 { get; set; }
        /// <summary>
        /// Gets or sets a base64-encoded SHA384 hash of the file
        /// </summary>
        public String SHA384 { get; set; }
        /// <summary>
        /// Gets or sets a base64-encoded SHA512 hash of the file
        /// </summary>
        public String SHA512 { get; set; }

        public override Boolean Equals(Object obj) {
            if (ReferenceEquals(null, obj)) return false;
            if (ReferenceEquals(this, obj)) return true;
            if (obj.GetType() != GetType()) return false;
            return Equals((FcivFileEntry) obj);
        }
        protected Boolean Equals(FcivFileEntry other) {
            return String.Equals(Name, other.Name, StringComparison.InvariantCultureIgnoreCase);
        }
        public override Int32 GetHashCode() {
            return StringComparer.InvariantCultureIgnoreCase.GetHashCode(Name);
        }
    }
}