using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace PsFCIV.Support {
    /// <summary>
    /// Contains helper cryptographic functions.
    /// </summary>
    public static class CryptUtils {
        /// <summary>
        /// Formats binary data as string.
        /// </summary>
        /// <param name="bytes">Byte array to format.</param>
        /// <param name="type">Format type.</param>
        /// <returns>Formatted string.</returns>
        public static String FormatBytes(Byte[] bytes, HashFormatType type) {
            switch (type) {
                case HashFormatType.Hex:
                    var sb = new StringBuilder();
                    foreach (Byte b in bytes) {
                        sb.AppendFormat("{0:X2}", b);
                    }
                    return sb.ToString();
                case HashFormatType.Base64:
                    return Convert.ToBase64String(bytes);
                default:
                    throw new ArgumentOutOfRangeException(nameof(type), type, null);
            }
        }
        /// <summary>
        /// Calculates a cryptographic hash of a file.
        /// </summary>
        /// <param name="path">Path to a file to calculate hash for.</param>
        /// <param name="hAlg">Algorithm to use for hashing.</param>
        /// <returns>Computed hash bytes.</returns>
        public static Byte[] HashFile(String path, HashAlgorithmType hAlg) {
            using (var hasher = HashAlgorithm.Create(hAlg.ToString())) {
                using (var fStream = new StreamReader(path)) {
                    return hasher.ComputeHash(fStream.BaseStream);
                }
            }
        }
    }
}