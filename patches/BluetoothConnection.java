package io.github.edufolly.flutterbluetoothserial;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Method;
import java.util.UUID;
import java.util.Arrays;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import android.util.Log;

/// Universal Bluetooth serial connection class (for Java)
///
/// PATCHED 2026: the original connect() only ever tried
/// device.createRfcommSocketToServiceRecord(uuid) followed by socket.connect().
/// On Android 12+ (and on many OEM Bluetooth stacks, e.g. some MediaTek/Unisoc
/// chipsets used in budget phones) that secure, SDP-based socket frequently
/// fails during the handshake with:
///   java.io.IOException: read failed, socket might closed or timeout, read ret: -1
/// even though the exact same code works fine on Android 10/11.
///
/// This is a widely reported issue against this plugin (and against raw
/// BluetoothSocket usage in general) -- see e.g. issues #18, #50, #146, #150,
/// #154, #164 on edufolly/flutter_bluetooth_serial. There is no single root
/// cause acknowledged by Google, but the community workaround that reliably
/// resolves it is to fall back, in order, to:
///   1) the original secure RFCOMM socket bound via SDP (unchanged behavior)
///   2) an *insecure* RFCOMM socket bound via SDP (skips the extra
///      authentication handshake step that trips up some Android 12+/OEM
///      stacks)
///   3) a raw RFCOMM socket bound directly to channel 1 via the hidden
///      `createRfcommSocket(int channel)` method, reached through reflection
///      (bypasses SDP entirely -- this is the same trick many native Android
///      Bluetooth chat apps use as a last resort)
/// Each attempt is retried with a short delay before moving to the next
/// method, since on some devices the very first attempt after cancelDiscovery()
/// is transiently unstable.
public abstract class BluetoothConnection
{
    private static final String TAG = "BluetoothConnection";
    protected static final UUID DEFAULT_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");

    protected BluetoothAdapter bluetoothAdapter;

    protected ConnectionThread connectionThread = null;

    public boolean isConnected() {
        return connectionThread != null && connectionThread.requestedClosing != true;
    }



    public BluetoothConnection(BluetoothAdapter bluetoothAdapter) {
        this.bluetoothAdapter = bluetoothAdapter;
    }



    /// Connects to given device by hardware address, trying multiple socket
    /// strategies so the connection survives on Android 12+ / flaky OEM
    /// Bluetooth stacks, not just on Android <=11.
    public void connect(String address, UUID uuid) throws IOException {
        if (isConnected()) {
            throw new IOException("already connected");
        }

        BluetoothDevice device = bluetoothAdapter.getRemoteDevice(address);
        if (device == null) {
            throw new IOException("device not found");
        }

        // Cancel discovery, even though we didn't start it -- an active scan
        // is a common cause of RFCOMM connect() failing outright.
        bluetoothAdapter.cancelDiscovery();

        IOException lastError = null;
        BluetoothSocket socket = null;

        // --- Attempt 1: secure socket via SDP (original behavior) ---
        try {
            socket = device.createRfcommSocketToServiceRecord(uuid);
            connectSocket(socket);
            Log.i(TAG, "Connected using secure createRfcommSocketToServiceRecord");
        } catch (IOException e) {
            lastError = e;
            Log.w(TAG, "Secure SDP socket failed, trying insecure: " + e.getMessage());
            closeQuietly(socket);
            socket = null;
            sleepQuietly(300);
        }

        // --- Attempt 2: insecure socket via SDP ---
        if (socket == null || !socket.isConnected()) {
            try {
                socket = device.createInsecureRfcommSocketToServiceRecord(uuid);
                connectSocket(socket);
                Log.i(TAG, "Connected using insecure createInsecureRfcommSocketToServiceRecord");
            } catch (IOException e) {
                lastError = e;
                Log.w(TAG, "Insecure SDP socket failed, trying reflection channel 1: " + e.getMessage());
                closeQuietly(socket);
                socket = null;
                sleepQuietly(300);
            }
        }

        // --- Attempt 3: raw RFCOMM channel 1 via reflection (bypasses SDP) ---
        if (socket == null || !socket.isConnected()) {
            try {
                socket = createRfcommSocketViaReflection(device, 1);
                connectSocket(socket);
                Log.i(TAG, "Connected using reflection createRfcommSocket(channel=1)");
            } catch (Exception e) {
                lastError = (e instanceof IOException) ? (IOException) e : new IOException(e);
                closeQuietly(socket);
                socket = null;
            }
        }

        if (socket == null || !socket.isConnected()) {
            throw (lastError != null) ? lastError : new IOException("socket connection not established");
        }

        connectionThread = new ConnectionThread(socket);
        connectionThread.start();
    }
    /// Connects to given device by hardware address (default UUID used)
    public void connect(String address) throws IOException {
        connect(address, DEFAULT_UUID);
    }

    /// Tries socket.connect() up to twice (some stacks fail once, then work
    /// immediately on retry, without needing to fall back to a different
    /// socket type at all).
    private void connectSocket(BluetoothSocket socket) throws IOException {
        if (socket == null) {
            throw new IOException("socket connection not established");
        }
        try {
            socket.connect();
        } catch (IOException first) {
            sleepQuietly(250);
            socket.connect();
        }
    }

    /// Reaches the hidden BluetoothDevice#createRfcommSocket(int) method that
    /// binds directly to an RFCOMM channel without going through SDP lookup.
    /// This is not part of the public Android API but has been stable across
    /// AOSP versions and is the standard last-resort fallback used by native
    /// Bluetooth chat/terminal apps.
    private BluetoothSocket createRfcommSocketViaReflection(BluetoothDevice device, int channel) throws Exception {
        Method m = device.getClass().getMethod("createRfcommSocket", new Class[] {int.class});
        return (BluetoothSocket) m.invoke(device, channel);
    }

    private void closeQuietly(BluetoothSocket socket) {
        if (socket == null) return;
        try { socket.close(); } catch (Exception ignored) {}
    }

    private void sleepQuietly(long millis) {
        try { Thread.sleep(millis); } catch (InterruptedException ignored) {}
    }

    /// Disconnects current session (ignore if not connected)
    public void disconnect() {
        if (isConnected()) {
            connectionThread.cancel();
            connectionThread = null;
        }
    }

    /// Writes to connected remote device 
    public void write(byte[] data) throws IOException {
        if (!isConnected()) {
            throw new IOException("not connected");
        }

        connectionThread.write(data);
    }

    /// Callback for reading data.
    protected abstract void onRead(byte[] data);

    /// Callback for disconnection.
    protected abstract void onDisconnected(boolean byRemote);

    /// Thread to handle connection I/O
    private class ConnectionThread extends Thread  {
        private final BluetoothSocket socket;
        private final InputStream input;
        private final OutputStream output;
        private boolean requestedClosing = false;
        
        ConnectionThread(BluetoothSocket socket) {
            this.socket = socket;
            InputStream tmpIn = null;
            OutputStream tmpOut = null;

            try {
                tmpIn = socket.getInputStream();
                tmpOut = socket.getOutputStream();
            } catch (IOException e) {
                e.printStackTrace();
            }

            this.input = tmpIn;
            this.output = tmpOut;
        }

        /// Thread main code
        public void run() {
            byte[] buffer = new byte[1024];
            int bytes;

            while (!requestedClosing) {
                try {
                    bytes = input.read(buffer);

                    onRead(Arrays.copyOf(buffer, bytes));
                } catch (IOException e) {
                    // `input.read` throws when closed by remote device
                    break;
                }
            }

            // Make sure output stream is closed
            if (output != null) {
                try {
                    output.close();
                }
                catch (Exception e) {}
            }

            // Make sure input stream is closed
            if (input != null) {
                try {
                    input.close();
                }
                catch (Exception e) {}
            }

            // Callback on disconnected, with information which side is closing
            onDisconnected(!requestedClosing);

            // Just prevent unnecessary `cancel`ing
            requestedClosing = true;
        }

        /// Writes to output stream
        public void write(byte[] bytes) {
            try {
                output.write(bytes);
            } catch (IOException e) {
                e.printStackTrace();
            }
        }

        /// Stops the thread, disconnects
        public void cancel() {
            if (requestedClosing) {
                return;
            }
            requestedClosing = true;

            // Flush output buffers befoce closing
            try {
                output.flush();
            }
            catch (Exception e) {}

            // Close the connection socket
            if (socket != null) {
                try {
                    // Might be useful (see https://stackoverflow.com/a/22769260/4880243)
                    Thread.sleep(111);

                    socket.close();
                }
                catch (Exception e) {}
            }
        }
    }
}
