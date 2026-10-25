import com.android.apksig.ApkSigner;
import com.android.apksig.ApkVerifier;
import java.io.*;
import java.nio.file.*;
import java.security.*;
import java.security.cert.*;
import java.util.*;

/** Minimal stand-in for the Android SDK "apksigner" (sign/verify), built on the apksig library. */
public class ApkSignerTool {
    public static void main(String[] args) throws Exception {
        if (args.length == 0) { System.err.println("usage: apksigner sign|verify ..."); System.exit(2); }
        String cmd = args[0];
        if (cmd.equals("--version") || cmd.equals("version")) { System.out.println("0.9"); return; }
        Map<String, String> opt = new HashMap<>();
        String apk = null;
        for (int i = 1; i < args.length; i++) {
            String a = args[i];
            if (a.equals("--verbose") || a.equals("-v") || a.equals("--print-certs")) continue;
            if (a.startsWith("--")) { opt.put(a, i + 1 < args.length ? args[++i] : ""); continue; }
            apk = a;
        }
        if (apk == null) { System.err.println("no apk given"); System.exit(2); }
        if (cmd.equals("verify")) {
            ApkVerifier.Result r = new ApkVerifier.Builder(new File(apk)).build().verify();
            for (Object e : r.getErrors()) System.err.println("ERROR: " + e);
            System.out.println(r.isVerified() ? "Verifies (v1=" + r.isVerifiedUsingV1Scheme() + ", v2=" + r.isVerifiedUsingV2Scheme() + ")" : "DOES NOT VERIFY");
            System.exit(r.isVerified() ? 0 : 1);
        }
        if (!cmd.equals("sign")) { System.err.println("unknown command " + cmd); System.exit(2); }
        String ks = opt.get("--ks");
        String pass = opt.getOrDefault("--ks-pass", "pass:android");
        if (pass.startsWith("pass:")) pass = pass.substring(5);
        String alias = opt.get("--ks-key-alias");
        KeyStore store;
        try {
            store = KeyStore.getInstance("JKS");
            try (InputStream in = new FileInputStream(ks)) { store.load(in, pass.toCharArray()); }
        } catch (Exception e) {
            store = KeyStore.getInstance("PKCS12");
            try (InputStream in = new FileInputStream(ks)) { store.load(in, pass.toCharArray()); }
        }
        if (alias == null) alias = store.aliases().nextElement();
        String keyPass = opt.getOrDefault("--key-pass", "pass:" + pass);
        if (keyPass.startsWith("pass:")) keyPass = keyPass.substring(5);
        PrivateKey key = (PrivateKey) store.getKey(alias, keyPass.toCharArray());
        List<X509Certificate> certs = new ArrayList<>();
        for (java.security.cert.Certificate c : store.getCertificateChain(alias)) certs.add((X509Certificate) c);
        ApkSigner.SignerConfig cfg = new ApkSigner.SignerConfig.Builder("CERT", key, certs).build();
        File in = new File(apk);
        File out = new File(opt.getOrDefault("--out", apk + ".signed.tmp"));
        ApkSigner.Builder b = new ApkSigner.Builder(Collections.singletonList(cfg)).setInputApk(in).setOutputApk(out);
        if (opt.containsKey("--min-sdk-version")) b.setMinSdkVersion(Integer.parseInt(opt.get("--min-sdk-version")));
        b.build().sign();
        if (!opt.containsKey("--out")) Files.move(out.toPath(), in.toPath(), StandardCopyOption.REPLACE_EXISTING);
        System.out.println("Signed");
    }
}
