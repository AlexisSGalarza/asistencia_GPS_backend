"""
Backend de email personalizado que omite la verificación SSL del certificado.
Útil en desarrollo donde el servidor Mac no tiene los certificados CA instalados.

Para instalar certificados correctamente en Mac (solución definitiva):
    /Applications/Python\ 3.x/Install\ Certificates.command
O:
    pip install certifi
"""
import ssl
from django.core.mail.backends.smtp import EmailBackend as DjangoSMTPBackend


class NoSSLVerifyEmailBackend(DjangoSMTPBackend):
    """
    Igual que el backend SMTP de Django pero con verificación SSL desactivada.
    Solo usar en desarrollo. En producción instala los certs correctamente.
    """

    def open(self):
        if self.connection:
            return False

        # Crear contexto SSL sin verificación de certificado
        self._ssl_context = ssl.create_default_context()
        self._ssl_context.check_hostname = False
        self._ssl_context.verify_mode = ssl.CERT_NONE

        import smtplib
        connection_params = {
            'local_hostname': None,
        }
        if self.timeout is not None:
            connection_params['timeout'] = self.timeout

        try:
            if self.use_ssl:
                connection_params['context'] = self._ssl_context
                self.connection = smtplib.SMTP_SSL(
                    self.host, self.port, **connection_params
                )
            else:
                self.connection = smtplib.SMTP(
                    self.host, self.port, **connection_params
                )
            if not self.use_ssl and self.use_tls:
                self.connection.ehlo()
                self.connection.starttls(context=self._ssl_context)
                self.connection.ehlo()
            if self.username and self.password:
                self.connection.login(self.username, self.password)
            return True
        except Exception:
            if not self.fail_silently:
                raise
